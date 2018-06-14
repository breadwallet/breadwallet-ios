//
//  ApplicationController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-21.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit
import BRCore

private let timeSinceLastExitKey = "TimeSinceLastExit"
private let shouldRequireLoginTimeoutKey = "ShouldRequireLoginTimeoutKey"

class ApplicationController : Subscriber, Trackable {

    let window = UIWindow()
    private var startFlowController: StartFlowPresenter?
    private var modalPresenter: ModalPresenter?
    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .light))
    private var walletManagers = [String: WalletManager]()
    private var walletCoordinator: WalletCoordinator?
    private var exchangeUpdater: ExchangeUpdater?
    private var feeUpdaters = [String: FeeUpdater]()
    private var primaryWalletManager: BTCWalletManager? {
        return walletManagers[Currencies.btc.code] as? BTCWalletManager
    }
    
    private var kvStoreCoordinator: KVStoreCoordinator?
    fileprivate var application: UIApplication?
    private var urlController: URLController?
    private var defaultsUpdater: UserDefaultsUpdater?
    private var reachability = ReachabilityMonitor()
    private let noAuthApiClient = BRAPIClient(authenticator: NoAuthAuthenticator())
    private var fetchCompletionHandler: ((UIBackgroundFetchResult) -> Void)?
    private var launchURL: URL?
    private var hasPerformedWalletDependentInitialization = false
    private var didInitWallet = false

    // MARK: -

    init() {
        guardProtected(queue: DispatchQueue.walletQueue) {
            if UserDefaults.hasBchConnected {
                self.initWallet(completion: self.didAttemptInitWallet)
            } else {
                self.initWalletWithMigration(completion: self.didAttemptInitWallet)
            }
        }
    }

    /// Migrate pre-fork BTC transactions to BCH wallet
    private func initWalletWithMigration(completion: @escaping () -> Void) {
        let btc = Currencies.btc
        let bch = Currencies.bch
        guard let btcWalletManager = try? BTCWalletManager(currency: btc, dbPath: btc.dbPath) else { return }
        walletManagers[btc.code] = btcWalletManager
        btcWalletManager.initWallet { [unowned self] success in
            guard success else {
                completion()
                return
            }

            self.exchangeUpdater = ExchangeUpdater(currencies: Store.state.currencies, apiClient: self.primaryWalletManager!.apiClient!)
            btcWalletManager.initPeerManager {
                btcWalletManager.db?.loadTransactions { txns in
                    btcWalletManager.db?.loadBlocks { blocks in
                        let preForkTransactions = txns.compactMap{$0}.filter { $0.pointee.blockHeight < C.bCashForkBlockHeight }
                        let preForkBlocks = blocks.compactMap{$0}.filter { $0.pointee.height < C.bCashForkBlockHeight }
                        var bchWalletManager: BTCWalletManager?
                        if preForkBlocks.count > 0 || blocks.count == 0 {
                            bchWalletManager = try? BTCWalletManager(currency: bch, dbPath: bch.dbPath)
                        } else {
                            bchWalletManager = try? BTCWalletManager(currency: bch, dbPath: bch.dbPath, earliestKeyTimeOverride: C.bCashForkTimeStamp)
                        }
                        self.walletManagers[bch.code] = bchWalletManager
                        bchWalletManager?.initWallet(transactions: preForkTransactions)
                        bchWalletManager?.initPeerManager(blocks: preForkBlocks)
                        bchWalletManager?.db?.loadTransactions { storedTransactions in
                            if storedTransactions.count == 0 {
                                bchWalletManager?.wallet?.transactions.compactMap{$0}.forEach { txn in
                                    bchWalletManager?.db?.txAdded(txn)
                                }
                            }
                        }
                        // init other wallets
                        self.initWallet(completion: completion)
                    }
                }
            }
        }
    }

    private func initWallet(completion: @escaping () -> Void) {
        let dispatchGroup = DispatchGroup()
        Store.state.currencies.forEach { currency in
            if walletManagers[currency.code] == nil {
                initWallet(currency: currency, dispatchGroup: dispatchGroup)
            }
        }
        dispatchGroup.notify(queue: .main) {
            completion()
        }
    }

    private func initWallet(currency: CurrencyDef, dispatchGroup: DispatchGroup) {
        if let token = currency as? ERC20Token {
            guard let ethWalletManager = walletManagers[Currencies.eth.code] as? EthWalletManager else { return }
            ethWalletManager.tokens.append(token)
            walletManagers[currency.code] = ethWalletManager
            return
        }
        dispatchGroup.enter()
        if let currency = currency as? Ethereum {
            let manager = EthWalletManager()
            walletManagers[currency.code] = manager
            dispatchGroup.leave()
            return
        }
        guard let currency = currency as? Bitcoin else { return }
        guard let walletManager = try? BTCWalletManager(currency: currency, dbPath: currency.dbPath) else { return }
        walletManagers[currency.code] = walletManager
        walletManager.initWallet { success in
            guard success else {
                // always keep BTC wallet manager, even if not initialized, since it the primaryWalletManager and needed for onboarding
                if !currency.matches(Currencies.btc) {
                    walletManager.db?.close()
                    walletManager.db?.delete()
                    self.walletManagers[currency.code] = nil
                }
                dispatchGroup.leave()
                return
            }
            if currency.matches(Currencies.btc) {
                self.exchangeUpdater = ExchangeUpdater(currencies: Store.state.currencies, apiClient: self.primaryWalletManager!.apiClient!)
            }
            walletManager.initPeerManager {
                dispatchGroup.leave()
            }
        }
    }

    private func didAttemptInitWallet() {
        DispatchQueue.main.async {
            self.didInitWallet = true
            if !self.hasPerformedWalletDependentInitialization {
                self.didInitWalletManager()
            }
        }
    }

    func launch(application: UIApplication, options: [UIApplicationLaunchOptionsKey: Any]?) {
        self.application = application
        //application.setMinimumBackgroundFetchInterval(UIApplicationBackgroundFetchIntervalMinimum)
        application.setMinimumBackgroundFetchInterval(UIApplicationBackgroundFetchIntervalNever)
        setup()
        handleLaunchOptions(options)
        if reachability.isReachable {
            reachability.didChange = handleReachabilityLost
        } else {
            // app not reachable at launch
            self.reachability.didChange = { isReachable in
                if isReachable {
                    self.retryAfterIsReachable()
                    self.reachability.didChange = self.handleReachabilityLost
                }
            }
        }
        updateAssetBundles()
        if !hasPerformedWalletDependentInitialization && didInitWallet {
            didInitWalletManager()
        }
    }
    
    private func setup() {
        setupDefaults()
        setupAppearance()
        setupRootViewController()
        window.makeKeyAndVisible()
        listenForPushNotificationRequest()
        offMainInitialization()
        
        Store.subscribe(self, name: .reinitWalletManager(nil), callback: {
            guard let trigger = $0 else { return }
            if case .reinitWalletManager(let callback) = trigger {
                if let callback = callback {
                    self.reinitWalletManager(callback: callback)
                }
            }
        })
    }
    
    func willEnterForeground() {
        guard let walletManager = primaryWalletManager,
            !walletManager.noWallet else { return }
        walletManager.apiClient?.sendLaunchEvent()
        if shouldRequireLogin() {
            Store.perform(action: RequireLogin())
        }
        DispatchQueue.walletQueue.async {
            self.walletManagers[UserDefaults.mostRecentSelectedCurrencyCode]?.peerManager?.connect()
        }
        exchangeUpdater?.refresh(completion: {})
        feeUpdaters.values.forEach { $0.refresh() }
        walletManager.apiClient?.kv?.syncAllKeys { print("KV finished syncing. err: \(String(describing: $0))") }
        walletManager.apiClient?.updateFeatureFlags()
    }

    func didEnterBackground() {
        // disconnect synced peer managers
        Store.state.currencies.filter { $0.state?.syncState == .success }.forEach { currency in
            DispatchQueue.walletQueue.async {
                self.walletManagers[currency.code]?.peerManager?.disconnect()
            }
        }
        //Save the backgrounding time if the user is logged in
        if !Store.state.isLoginRequired {
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: timeSinceLastExitKey)
        }
        primaryWalletManager?.apiClient?.kv?.syncAllKeys { print("KV finished syncing. err: \(String(describing: $0))") }
    }

    func performFetch(_ completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        fetchCompletionHandler = completionHandler
    }

    func open(url: URL) -> Bool {
        if let urlController = urlController {
            return urlController.handleUrl(url)
        } else {
            launchURL = url
            return false
        }
    }

    private func didInitWalletManager() {
        guard let primaryWalletManager = primaryWalletManager else { return }
        guard let rootViewController = window.rootViewController as? RootNavigationController else { return }
        walletCoordinator = WalletCoordinator(walletManagers: walletManagers)
        primaryWalletManager.apiClient?.sendLaunchEvent()
        setupEthInitialState()
        addTokenCountChangeListener()
        Store.perform(action: PinLength.set(primaryWalletManager.pinLength))
        rootViewController.walletManager = primaryWalletManager
        if let homeScreen = rootViewController.viewControllers.first as? HomeScreenViewController {
            homeScreen.primaryWalletManager = primaryWalletManager
        }
        hasPerformedWalletDependentInitialization = true
        if modalPresenter != nil {
            Store.unsubscribe(modalPresenter!)
        }
        modalPresenter = ModalPresenter(walletManagers: walletManagers, window: window, apiClient: noAuthApiClient)
        startFlowController = StartFlowPresenter(walletManager: primaryWalletManager, rootViewController: rootViewController)
        
        walletManagers.values.forEach { walletManager in
            feeUpdaters[walletManager.currency.code] = FeeUpdater(walletManager: walletManager)
        }

        defaultsUpdater = UserDefaultsUpdater(walletManager: primaryWalletManager)
        urlController = URLController(walletManager: primaryWalletManager)
        if let url = launchURL {
            _ = urlController?.handleUrl(url)
            launchURL = nil
        }

        if UIApplication.shared.applicationState != .background {
            if primaryWalletManager.noWallet {
                addWalletCreationListener()
                Store.perform(action: ShowStartFlow())
            } else {
                DispatchQueue.walletQueue.async {
                    self.walletManagers[UserDefaults.mostRecentSelectedCurrencyCode]?.peerManager?.connect()
                }
                startDataFetchers()
            }

        //For when watch app launches app in background
        } else {
            DispatchQueue.walletQueue.async {
                self.walletManagers[UserDefaults.mostRecentSelectedCurrencyCode]?.peerManager?.connect()
                if self.fetchCompletionHandler != nil {
                    self.performBackgroundFetch()
                }
            }
        }
    }
    
    private func reinitWalletManager(callback: @escaping () -> Void) {
        Store.perform(action: Reset())
        self.setup()
        
        DispatchQueue.walletQueue.async {
            self.feeUpdaters.values.forEach({ $0.stop() })
            self.feeUpdaters.removeAll()
            self.walletManagers.values.forEach({ $0.resetForWipe() })
            self.walletManagers.removeAll()
            self.initWallet {
                DispatchQueue.main.async {
                    self.didInitWalletManager()
                    callback()
                }
            }
        }
    }

    private func setupEthInitialState() {
        guard let ethWalletManager = walletManagers[Currencies.eth.code] as? EthWalletManager else { return }
        ethWalletManager.apiClient = primaryWalletManager?.apiClient
        Store.perform(action: WalletChange(Currencies.eth).setSyncingState(.connecting))
        Store.perform(action: WalletChange(Currencies.eth).setMaxDigits(Currencies.eth.commonUnit.decimals))
        Store.perform(action: WalletID.set(ethWalletManager.walletID))
        
        Store.state.currencies.filter({ $0 is ERC20Token }).forEach { token in
            Store.perform(action: WalletChange(token).setSyncingState(.connecting))
            Store.perform(action: WalletChange(token).setMaxDigits(token.commonUnit.decimals))
            guard let state = token.state else { return }
            Store.perform(action: WalletChange(token).set(state.mutate(receiveAddress: ethWalletManager.address)))
        }
    }

    private func shouldRequireLogin() -> Bool {
        let then = UserDefaults.standard.double(forKey: timeSinceLastExitKey)
        let timeout = UserDefaults.standard.double(forKey: shouldRequireLoginTimeoutKey)
        let now = Date().timeIntervalSince1970
        return now - then > timeout
    }

    private func setupDefaults() {
        if UserDefaults.standard.object(forKey: shouldRequireLoginTimeoutKey) == nil {
            UserDefaults.standard.set(60.0*3.0, forKey: shouldRequireLoginTimeoutKey) //Default 3 min timeout
        }
    }

    private func setupAppearance() {
        UINavigationBar.appearance().titleTextAttributes = [NSAttributedStringKey.font: UIFont.header]
    }

    private func setupRootViewController() {
        let home = HomeScreenViewController(primaryWalletManager: walletManagers[Currencies.btc.code] as? BTCWalletManager)
        let nc = RootNavigationController()
        nc.pushViewController(home, animated: false)
        
        home.didSelectCurrency = { currency in
            guard let walletManager = self.walletManagers[currency.code] else { return }
            let accountViewController = AccountViewController(currency: currency, walletManager: walletManager)
            nc.pushViewController(accountViewController, animated: true)
        }
        
        home.didTapSupport = {
            self.modalPresenter?.presentFaq()
        }
        
        home.didTapSecurity = {
            self.modalPresenter?.presentSecurityCenter()
        }
        
        home.didTapSettings = {
            self.modalPresenter?.presentSettings()
        }

        home.didTapAddWallet = { [weak self] in
            guard let kvStore = self?.primaryWalletManager?.apiClient?.kv else { return }
            let vc = EditWalletsViewController(type: .manage, kvStore: kvStore)
            nc.pushViewController(vc, animated: true)
        }

        //State restoration
        if let currency = Store.state.currencies.first(where: { $0.code == UserDefaults.selectedCurrencyCode }),
            let walletManager = self.walletManagers[currency.code] {
            let accountViewController = AccountViewController(currency: currency, walletManager: walletManager)
            nc.pushViewController(accountViewController, animated: true)
        }

        window.rootViewController = nc
    }

    private func startDataFetchers() {
        guard let primaryWalletManager = primaryWalletManager else { return }
        primaryWalletManager.apiClient?.updateFeatureFlags()
        initKVStoreCoordinator()
        feeUpdaters.values.forEach { $0.refresh() }
        defaultsUpdater?.refresh()
        primaryWalletManager.apiClient?.events?.up()
    }
    
    private func handleReachabilityLost(isReachable: Bool) {
        if !isReachable {
            self.reachability.didChange = { isReachable in
                if isReachable {
                    self.retryAfterIsReachable()
                }
            }
        }
    }
    
    private func retryAfterIsReachable() {
        guard let walletManager = primaryWalletManager,
            !walletManager.noWallet else { return }
        walletManagers.values.filter { $0 is BTCWalletManager }.map { $0.currency }.forEach {
            // reset sync state before re-connecting
            Store.perform(action: WalletChange($0).setSyncingState(.success))
        }
        DispatchQueue.walletQueue.async {
            self.walletManagers[UserDefaults.mostRecentSelectedCurrencyCode]?.peerManager?.connect()
        }
        exchangeUpdater?.refresh(completion: {})
        feeUpdaters.values.forEach { $0.refresh() }
        walletManager.apiClient?.kv?.syncAllKeys { print("KV finished syncing. err: \(String(describing: $0))") }
        walletManager.apiClient?.updateFeatureFlags()
    }

    /// Handles new wallet creation or recovery
    private func addWalletCreationListener() {
        Store.subscribe(self, name: .didCreateOrRecoverWallet, callback: { _ in
            self.walletManagers.removeAll() // remove the empty wallet managers
            DispatchQueue.walletQueue.async {
                self.initWallet(completion: self.didInitWalletManager)
            }
        })
    }
    
    private func updateAssetBundles() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let myself = self else { return }
            myself.noAuthApiClient.updateBundles { errors in
                for (n, e) in errors {
                    print("Bundle \(n) ran update. err: \(String(describing: e))")
                }
                DispatchQueue.main.async {
                    let _ = myself.modalPresenter?.supportCenter // Initialize support center
                }
            }
        }
    }

    private func initKVStoreCoordinator() {
        guard let kvStore = primaryWalletManager?.apiClient?.kv else { return }
        guard kvStoreCoordinator == nil else { return }
        self.kvStoreCoordinator = KVStoreCoordinator(kvStore: kvStore)
        self.walletManagers.values.forEach({ $0.kvStore = kvStore })
        kvStore.syncAllKeys { [unowned self] error in
            print("KV finished syncing. err: \(String(describing: error))")
            self.kvStoreCoordinator?.setupStoredCurrencyList()
            self.kvStoreCoordinator?.retreiveStoredWalletInfo()
            self.kvStoreCoordinator?.listenForWalletChanges()
        }
    }

    private func offMainInitialization() {
        DispatchQueue.global(qos: .background).async {
            let _ = Rate.symbolMap //Initialize currency symbol map
        }
    }

    private func handleLaunchOptions(_ options: [UIApplicationLaunchOptionsKey: Any]?) {
        if let url = options?[.url] as? URL {
            do {
                let file = try Data(contentsOf: url)
                if file.count > 0 {
                    Store.trigger(name: .openFile(file))
                }
            } catch let error {
                print("Could not open file at: \(url), error: \(error)")
            }
        }
    }

    func performBackgroundFetch() {
//        saveEvent("appController.performBackgroundFetch")
//        let group = DispatchGroup()
//        if let peerManager = walletManager?.peerManager, peerManager.syncProgress(fromStartHeight: peerManager.lastBlockHeight) < 1.0 {
//            group.enter()
//            store.lazySubscribe(self, selector: { $0.walletState.syncState != $1.walletState.syncState }, callback: { state in
//                if self.fetchCompletionHandler != nil {
//                    if state.walletState.syncState == .success {
//                        DispatchQueue.walletQueue.async {
//                            peerManager.disconnect()
//                            group.leave()
//                        }
//                    }
//                }
//            })
//        }
//
//        group.enter()
//        Async.parallel(callbacks: [
//            { self.exchangeUpdater?.refresh(completion: $0) },
//            { self.feeUpdater?.refresh(completion: $0) },
//            { self.walletManager?.apiClient?.events?.sync(completion: $0) },
//            { self.walletManager?.apiClient?.updateFeatureFlags(); $0() }
//            ], completion: {
//                group.leave()
//        })
//
//        DispatchQueue.global(qos: .utility).async {
//            if group.wait(timeout: .now() + 25.0) == .timedOut {
//                self.saveEvent("appController.backgroundFetchFailed")
//                self.fetchCompletionHandler?(.failed)
//            } else {
//                self.saveEvent("appController.backgroundFetchNewData")
//                self.fetchCompletionHandler?(.newData)
//            }
//            self.fetchCompletionHandler = nil
//        }
    }

    func willResignActive() {
        applyBlurEffect()
        guard !Store.state.isPushNotificationsEnabled else { return }
        guard let pushToken = UserDefaults.pushToken else { return }
        primaryWalletManager?.apiClient?.deletePushNotificationToken(pushToken)
    }
    
    func didBecomeActive() {
        removeBlurEffect()
    }
    
    private func applyBlurEffect() {
        guard !Store.state.isLoginRequired && !Store.state.isPromptingBiometrics else { return }
        blurView.alpha = 1.0
        blurView.frame = window.frame
        window.addSubview(blurView)
    }
    
    private func removeBlurEffect() {
        let duration = Store.state.isLoginRequired ? 0.4 : 0.1 // keep content hidden if lock screen about to appear on top
        UIView.animate(withDuration: duration, animations: {
            self.blurView.alpha = 0.0
        }, completion: { _ in
            self.blurView.removeFromSuperview()
        })
    }

    private func addTokenCountChangeListener() {
        Store.subscribe(self, selector: {
            let oldTokens = Set($0.currencies.compactMap { ($0 as? ERC20Token)?.address })
            let newTokens = Set($1.currencies.compactMap { ($0 as? ERC20Token)?.address })
            return oldTokens != newTokens
        }, callback: { state in
            guard let ethWalletManager = self.walletManagers[Currencies.eth.code] as? EthWalletManager else { return }
            let tokens = state.currencies.compactMap { $0 as? ERC20Token }
            tokens.forEach { token in
                self.walletManagers[token.code] = ethWalletManager
                self.modalPresenter?.walletManagers[token.code] = ethWalletManager
                Store.perform(action: WalletChange(token).setMaxDigits(token.commonUnit.decimals))
                Store.perform(action: WalletChange(token).setSyncingState(.connecting))
                guard let state = token.state else { return }
                Store.perform(action: WalletChange(token).set(state.mutate(receiveAddress: ethWalletManager.address)))
            }
            ethWalletManager.tokens = tokens // triggers balance refresh
            self.exchangeUpdater?.refresh() {}
        })
    }
}

//MARK: - Push notifications
extension ApplicationController {
    func listenForPushNotificationRequest() {
        // TODO: notifications
//        Store.subscribe(self, name: .registerForPushNotificationToken, callback: { _ in
//            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { (granted, error) in
//                if granted {
//                    self.application?.registerForRemoteNotifications()
//                }
//            }
//        })
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
//        guard let apiClient = walletManager?.apiClient else { return }
//        guard UserDefaults.pushToken != deviceToken else { return }
//        UserDefaults.pushToken = deviceToken
//        apiClient.savePushNotificationToken(deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("didFailToRegisterForRemoteNotification: \(error)")
    }
}
