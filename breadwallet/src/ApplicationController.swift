//
//  ApplicationController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-21.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit
import BRCore
import UserNotifications

private let timeSinceLastExitKey = "TimeSinceLastExit"
private let shouldRequireLoginTimeoutKey = "ShouldRequireLoginTimeoutKey"

class ApplicationController : Subscriber, Trackable {

    let window = UIWindow()
    private var startFlowController: StartFlowPresenter?
    private var modalPresenter: ModalPresenter?
    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .light))
    private var walletManagers = [String: WalletManager]()
    private var walletCoordinator: WalletCoordinator?
    private var primaryWalletManager: BTCWalletManager? {
        return walletManagers[Currencies.btc.code] as? BTCWalletManager
    }
    
    private var kvStoreCoordinator: KVStoreCoordinator?
    fileprivate var application: UIApplication?
    private var urlController: URLController?
    private var defaultsUpdater: UserDefaultsUpdater?
    private var fetchCompletionHandler: ((UIBackgroundFetchResult) -> Void)?
    private var launchURL: URL?
    private var hasPerformedWalletDependentInitialization = false
    private var didInitWallet = false
    private let notificationHandler = NotificationHandler()
    private var isReachable = true {
        didSet {
            if oldValue == false && isReachable {
                self.retryAfterIsReachable()
            }
        }
    }
    // MARK: -

    init() {
        isReachable = Reachability.isReachable
        guardProtected(queue: DispatchQueue.walletQueue) {
            if UserDefaults.hasBchConnected {
                self.initWallets(completion: self.didAttemptInitWallet)
            } else {
                self.initWalletsWithMigration(completion: self.didAttemptInitWallet)
            }
        }
    }

    /// Migrates pre-fork BTC transactions to BCH wallet then init all wallets
    private func initWalletsWithMigration(completion: @escaping () -> Void) {
        let btc = Currencies.btc
        let bch = Currencies.bch
        guard let btcWalletManager = try? BTCWalletManager(currency: btc, dbPath: btc.dbPath) else { return }
        walletManagers[btc.code] = btcWalletManager
        btcWalletManager.initWallet { [unowned self] success in
            guard success else {
                completion()
                return
            }

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
                        self.initWallets(completion: completion)
                    }
                }
            }
        }
    }

    /// Inits all blockchain wallets
    private func initWallets(completion: @escaping () -> Void) {
        let dispatchGroup = DispatchGroup()
        Store.state.currencies.forEach { currency in
            if !(currency is ERC20Token) && walletManagers[currency.code] == nil {
                initWallet(currency: currency, dispatchGroup: dispatchGroup)
            }
        }
        dispatchGroup.notify(queue: .main) {
            completion()
        }
    }

    /// Inits the specified blockchain wallet
    private func initWallet(currency: CurrencyDef, dispatchGroup: DispatchGroup) {
        guard !(currency is ERC20Token) else { return assertionFailure() }
        dispatchGroup.enter()
        if let currency = currency as? Ethereum {
            guard let manager = EthWalletManager() else {
                dispatchGroup.leave()
                return
            }
            walletManagers[currency.code] = manager
            setupEthInitialState() {
                dispatchGroup.leave()
            }
            return
        }
        guard let currency = currency as? Bitcoin else { return assertionFailure() }
        guard let walletManager = try? BTCWalletManager(currency: currency, dbPath: currency.dbPath) else { return assertionFailure() }
        walletManagers[currency.code] = walletManager
        walletManager.initWallet { success in
            guard success else {
                // always keep BTC wallet manager, even if not initialized, since it the primaryWalletManager and needed for onboarding
                if !currency.matches(Currencies.btc) {
                    self.walletManagers[currency.code] = nil
                }
                dispatchGroup.leave()
                return
            }
            walletManager.initPeerManager {
                dispatchGroup.leave()
            }
        }
    }
    
    /// Init all Ethereum token wallets
    private func initTokenWallets() {
        guard let ethWalletManager = walletManagers[Currencies.eth.code] as? EthWalletManager else { return }
        let tokens = Store.state.currencies.compactMap { $0 as? ERC20Token }
        tokens.forEach { token in
            self.walletManagers[token.code] = ethWalletManager
            self.modalPresenter?.walletManagers[token.code] = ethWalletManager
            Store.perform(action: WalletChange(token).setSyncingState(.connecting))
            Store.perform(action: WalletChange(token).setMaxDigits(token.commonUnit.decimals))
            guard let state = token.state else { return }
            Store.perform(action: WalletChange(token).set(state.mutate(receiveAddress: ethWalletManager.address)))
        }
        ethWalletManager.tokens = tokens
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
        application.setMinimumBackgroundFetchInterval(UIApplicationBackgroundFetchIntervalNever)
        UNUserNotificationCenter.current().delegate = notificationHandler
        setup()
        handleLaunchOptions(options)
        Reachability.addDidChangeCallback({ isReachable in
            self.isReachable = isReachable
        })
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
        offMainInitialization()
        
        Store.subscribe(self, name: .reinitWalletManager(nil), callback: {
            guard let trigger = $0 else { return }
            if case .reinitWalletManager(let callback) = trigger {
                if let callback = callback {
                    self.reinitWalletManager(callback: callback)
                }
            }
        })
        
        Store.lazySubscribe(self,
                            selector: { $0.isLoginRequired != $1.isLoginRequired && $1.isLoginRequired == false },
                            callback: { _ in self.didUnlockWallet() }
        )
    }
    
    func willEnterForeground() {
        guard let walletManager = primaryWalletManager,
            !walletManager.noWallet else { return }
        Backend.sendLaunchEvent()
        if shouldRequireLogin() {
            Store.perform(action: RequireLogin())
        }
        DispatchQueue.walletQueue.async {
            self.walletManagers[UserDefaults.mostRecentSelectedCurrencyCode]?.peerManager?.connect()
        }
        updateTokenList() {}
        updateAssetBundles()
        Backend.updateExchangeRates()
        Backend.updateFees()
        Backend.kvStore?.syncAllKeys { print("KV finished syncing. err: \(String(describing: $0))") }
        Backend.apiClient.updateFeatureFlags()
        if !Store.state.isLoginRequired {
            Backend.pigeonExchange?.fetchInbox()
        }
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
        Backend.kvStore?.syncAllKeys { print("KV finished syncing. err: \(String(describing: $0))") }
    }
    
    func didUnlockWallet() {
        Backend.pigeonExchange?.fetchInbox()
    }

    func performFetch(_ completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        fetchCompletionHandler = completionHandler
    }

    private func didInitWalletManager() {
        guard let primaryWalletManager = primaryWalletManager else { return }
        guard let rootViewController = window.rootViewController as? RootNavigationController else { return }
        walletCoordinator = WalletCoordinator(walletManagers: walletManagers)
        Backend.connectWallet(primaryWalletManager, currencies: Store.state.currencies, walletManagers: walletManagers.map { $0.1 })
        Backend.sendLaunchEvent()

        if let ethWalletManager = walletManagers[Currencies.eth.code] as? EthWalletManager {
            ethWalletManager.apiClient = Backend.apiClient
        }
        
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
        modalPresenter = ModalPresenter(walletManagers: walletManagers, window: window)
        startFlowController = StartFlowPresenter(walletManager: primaryWalletManager, rootViewController: rootViewController)

        defaultsUpdater = UserDefaultsUpdater(walletManager: primaryWalletManager)
        urlController = URLController(walletManager: primaryWalletManager)
        if let url = launchURL {
            _ = urlController?.handleUrl(url)
            launchURL = nil
        }
        
        if primaryWalletManager.noWallet {
            addWalletCreationListener()
            Store.perform(action: ShowStartFlow())
        } else {
            DispatchQueue.walletQueue.async {
                self.walletManagers[UserDefaults.mostRecentSelectedCurrencyCode]?.peerManager?.connect()
            }
            startDataFetchers()
        }
    }
    
    private func reinitWalletManager(callback: @escaping () -> Void) {
        Store.perform(action: Reset())
        self.setup()
        
        DispatchQueue.walletQueue.async {
            Backend.disconnectWallet()
            self.kvStoreCoordinator = nil
            self.walletManagers.values.forEach({ $0.resetForWipe() })
            self.walletManagers.removeAll()
            self.initWallets {
                DispatchQueue.main.async {
                    self.didInitWalletManager()
                    callback()
                }
            }
        }
    }

    private func setupEthInitialState(completion: @escaping () -> Void) {
        guard let ethWalletManager = walletManagers[Currencies.eth.code] as? EthWalletManager else { return assertionFailure() }
        DispatchQueue.main.async {
            Store.perform(action: WalletChange(Currencies.eth).setSyncingState(.connecting))
            Store.perform(action: WalletChange(Currencies.eth).setMaxDigits(Currencies.eth.commonUnit.decimals))
            Store.perform(action: WalletID.set(ethWalletManager.walletID))
        }
        updateTokenList() {
            completion()
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
        let backImage = #imageLiteral(resourceName: "Back").image(withInsets: UIEdgeInsets(top: 0.0, left: 8.0, bottom: 2.0, right: 0.0))
        UINavigationBar.appearance().backIndicatorImage = backImage
        UINavigationBar.appearance().backIndicatorTransitionMaskImage = backImage
        // hide back button text
        if #available(iOS 11, *) {
            UIBarButtonItem.appearance().setBackButtonBackgroundImage(#imageLiteral(resourceName: "TransparentPixel"), for: .normal, barMetrics: .default)
        } else {
            UIBarButtonItem.appearance().setBackButtonTitlePositionAdjustment(UIOffsetMake(-200, 0), for: .default)
        }
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
        
        home.didTapBuy = {
            Store.perform(action: RootModalActions.Present(modal: .buy(currency: nil)))
        }
        
        home.didTapTrade = {
            Store.perform(action: RootModalActions.Present(modal: .trade))
        }
        
        home.didTapMenu = {
            self.modalPresenter?.presentMenu()
        }

        home.didTapAddWallet = {
            guard let kvStore = Backend.kvStore else { return }
            let vc = EditWalletsViewController(type: .add, kvStore: kvStore)
            nc.pushViewController(vc, animated: true)
        }

        //State restoration
        if let currency = Store.state.currencies.first(where: { $0.code == UserDefaults.selectedCurrencyCode }),
            let walletManager = self.walletManagers[currency.code],
            primaryWalletManager?.noWallet == false {
            let accountViewController = AccountViewController(currency: currency, walletManager: walletManager)
            nc.pushViewController(accountViewController, animated: true)
        }

        window.rootViewController = nc
    }

    private func startDataFetchers() {
        Backend.apiClient.updateFeatureFlags()
        initKVStoreCoordinator()
        Backend.updateFees()
        Backend.updateExchangeRates()
        defaultsUpdater?.refresh()
        Backend.apiClient.events?.up()
        if !Store.state.isPushNotificationsEnabled {
            Backend.pigeonExchange?.startPolling()
        }
    }
    
    private func updateTokenList(completion: @escaping () -> Void) {
        guard let ethWalletManager = walletManagers[Currencies.eth.code] as? EthWalletManager else { return assertionFailure() }
        let processTokens: ([ERC20Token]) -> Void = { tokens in
            var tokens = tokens.sorted(by: { $0.code.lowercased() < $1.code.lowercased() })
            if E.isDebug {
                tokens.append(Currencies.tst)
            }
            ethWalletManager.setAvailableTokens(tokens)
            DispatchQueue.main.async {
                Store.perform(action: ManageWallets.setAvailableTokens(tokens))
            }
            print("[TokenList] tokens updated: \(tokens.count) tokens")
            completion()
        }
        
        let fm = FileManager.default
        let documentsDir = try! fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        let cachedFilePath = documentsDir.appendingPathComponent("tokens.json").path
        
        if let embeddedFilePath = Bundle.main.path(forResource: "tokens", ofType: "json"), !fm.fileExists(atPath: cachedFilePath) {
            do {
                try fm.copyItem(atPath: embeddedFilePath, toPath: cachedFilePath)
                print("[TokenList] copied bundle tokens list to cache")
            } catch let e {
                print("[TokenList] unable to copy bundled \(embeddedFilePath) -> \(cachedFilePath): \(e)")
            }
        }
        // fetch from network and update cached copy on success or return the cached copy if fetch fails
        Backend.apiClient.getTokenList() { result in
            switch result {
            case .success(let tokens):
                DispatchQueue.global(qos: .utility).async {
                    // update cache
                    do {
                        let data = try JSONEncoder().encode(tokens)
                        try data.write(to: URL(fileURLWithPath: cachedFilePath))
                    } catch let e {
                        print("[TokenList] failed to write to cache: \(e.localizedDescription)")
                    }
                }
                processTokens(tokens)
                
            case .error(let error):
                print("[TokenList] error fetching tokens: \(error)")
                var tokens = [ERC20Token]()
                do {
                    print("[TokenList] using cached token list")
                    let cachedData = try Data(contentsOf: URL(fileURLWithPath: cachedFilePath))
                    tokens = try JSONDecoder().decode([ERC20Token].self, from: cachedData)
                } catch let e {
                    print("[TokenList] error reading from cache: \(e)")
                    assertionFailure()
                }
                processTokens(tokens)
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
        updateTokenList() {}
        Backend.updateExchangeRates()
        Backend.updateFees()
        Backend.kvStore?.syncAllKeys { print("KV finished syncing. err: \(String(describing: $0))") }
        Backend.apiClient.updateFeatureFlags()
    }

    /// Handles new wallet creation or recovery
    private func addWalletCreationListener() {
        Store.subscribe(self, name: .didCreateOrRecoverWallet, callback: { _ in
            self.walletManagers.removeAll() // remove the empty wallet managers
            DispatchQueue.walletQueue.async {
                self.initWallets(completion: self.didInitWalletManager)
            }
            Store.perform(action: LoginSuccess())
        })
    }
    
    private func updateAssetBundles() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let `self` = self else { return }
            Backend.apiClient.updateBundles { errors in
                for (n, e) in errors {
                    print("Bundle \(n) ran update. err: \(String(describing: e))")
                }
                DispatchQueue.main.async {
                    let _ = self.modalPresenter?.supportCenter // Initialize support center
                }
            }
        }
    }

    private func initKVStoreCoordinator() {
        guard let kvStore = Backend.kvStore else { return }
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

    func willResignActive() {
        applyBlurEffect()
        if !Store.state.isPushNotificationsEnabled, let pushToken = UserDefaults.pushToken {
            Backend.apiClient.deletePushNotificationToken(pushToken)
        }
    }
    
    func didBecomeActive() {
        removeBlurEffect()
        // check if notification settings changed
        NotificationAuthorizer().areNotificationsAuthorized { authorized in
            DispatchQueue.main.async {
                if authorized {
                    if !Store.state.isPushNotificationsEnabled {
                        self.saveEvent("push.enabledSettings")
                    }
                    UIApplication.shared.registerForRemoteNotifications()
                } else {
                    if Store.state.isPushNotificationsEnabled, let pushToken = UserDefaults.pushToken {
                        self.saveEvent("push.disabledSettings")
                        Store.perform(action: PushNotifications.setIsEnabled(false))
                        Backend.apiClient.deletePushNotificationToken(pushToken)
                    }
                }
            }
        }
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
            self.initTokenWallets()
            Backend.updateExchangeRates()
        })
    }
}

extension ApplicationController {
    func open(url: URL) -> Bool {
        if let urlController = urlController {
            return urlController.handleUrl(url)
        } else {
            launchURL = url
            return false
        }
    }
    
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([Any]?) -> Void) -> Bool {
        if userActivity.activityType == NSUserActivityTypeBrowsingWeb {
            return open(url: userActivity.webpageURL!)
        }
        return false
    }
}

//MARK: - Push notifications
extension ApplicationController {
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        guard UserDefaults.pushToken != deviceToken else { return }
        UserDefaults.pushToken = deviceToken
        Backend.apiClient.savePushNotificationToken(deviceToken)
        Store.perform(action: PushNotifications.setIsEnabled(true))
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("[PUSH] failed to register for remote notifications: \(error.localizedDescription)")
        Store.perform(action: PushNotifications.setIsEnabled(false))
    }
}
