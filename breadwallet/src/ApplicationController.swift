//
//  ApplicationController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-21.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit
import BRCore
import Geth

private let timeSinceLastExitKey = "TimeSinceLastExit"
private let shouldRequireLoginTimeoutKey = "ShouldRequireLoginTimeoutKey"


let tokens = {
    return E.isTestnet ? [tst] : [xjp]
}()

class ApplicationController : Subscriber, Trackable {

    //Ideally the window would be private, but is unfortunately required
    //by the UIApplicationDelegate Protocol
    let window = UIWindow()
    fileprivate let store = Store()
    fileprivate let ethStore = Store()
    fileprivate let tokenStores: [Store] = {
        tokens.map {
            let store = Store()
            store.perform(action: CurrencyActions.set(.token))
            store.perform(action: ExchangeRates.setRate(Rate(code: "USD", name: "USD", rate: 305.0)))
            store.perform(action: WalletChange.set(store.state.walletState.mutate(token: $0)))
            return store
        }
    }()
    private var startFlowController: StartFlowPresenter?
    private var modalPresenter: ModalPresenter?

    fileprivate var walletManager: WalletManager?
    private var walletCoordinator: WalletCoordinator?
    private var ethWalletCoordinator: EthWalletCoordinator?
    private var tokenWalletCoordinators: [TokenWalletCoordinator]?
    private var exchangeUpdater: ExchangeUpdater?
    private var feeUpdater: FeeUpdater?
    private let transitionDelegate: ModalTransitionDelegate
    private var kvStoreCoordinator: KVStoreCoordinator?
    private var accountViewController: AccountViewController?
    private var ethAccountViewController: AccountViewController?
    private var containerViewController: AppContainerViewController?
    fileprivate var application: UIApplication?
    private let watchSessionManager = PhoneWCSessionManager()
    private var urlController: URLController?
    private var defaultsUpdater: UserDefaultsUpdater?
    private var reachability = ReachabilityMonitor()
    private let noAuthApiClient = BRAPIClient(authenticator: NoAuthAuthenticator())
    private var fetchCompletionHandler: ((UIBackgroundFetchResult) -> Void)?
    private var launchURL: URL?
    private var hasPerformedWalletDependentInitialization = false
    private var didInitWallet = false
    private var accountViewControllers: [AccountViewController]?

    init() {
        transitionDelegate = ModalTransitionDelegate(type: .transactionDetail, store: store)
        ethStore.perform(action: CurrencyActions.set(.ethereum))
        ethStore.perform(action: ExchangeRates.setRate(Rate(code: "USD", name: "USD", rate: 305.0)))

        DispatchQueue.walletQueue.async {
            guardProtected(queue: DispatchQueue.walletQueue) {
                self.initWallet()
            }
        }
    }

    private func initWallet() {
        self.walletManager = try? WalletManager(store: self.store, dbPath: nil)
        let _ = self.walletManager?.wallet //attempt to initialize wallet
        DispatchQueue.main.async {
            self.didInitWallet = true
            if !self.hasPerformedWalletDependentInitialization {
                self.didInitWalletManager()
            }
        }
    }

    func launch(application: UIApplication, options: [UIApplicationLaunchOptionsKey: Any]?) {
        self.application = application
        application.setMinimumBackgroundFetchInterval(UIApplicationBackgroundFetchIntervalMinimum)
        setup()
        handleLaunchOptions(options)
        reachability.didChange = { isReachable in
            if !isReachable {
                self.reachability.didChange = { isReachable in
                    if isReachable {
                        self.retryAfterIsReachable()
                    }
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
        store.subscribe(self, name: .reinitWalletManager(nil), callback: {
            guard let trigger = $0 else { return }
            if case .reinitWalletManager(let callback) = trigger {
                if let callback = callback {
                    self.store.removeAllSubscriptions()
                    self.store.perform(action: Reset())
                    self.setup()
                    DispatchQueue.walletQueue.async {
                        do {
                            self.walletManager = try WalletManager(store: self.store, dbPath: nil)
                            let _ = self.walletManager?.wallet //attempt to initialize wallet
                        } catch let error {
                            assert(false, "Error creating new wallet: \(error)")
                        }
                        DispatchQueue.main.async {
                            self.didInitWalletManager()
                            callback()
                        }
                    }
                }
            }
        })
    }

    func willEnterForeground() {
        guard let walletManager = walletManager else { return }
        guard !walletManager.noWallet else { return }
        if shouldRequireLogin() {
            store.perform(action: RequireLogin())
        }
        DispatchQueue.walletQueue.async {
            walletManager.peerManager?.connect()
        }
        exchangeUpdater?.refresh(completion: {})
        feeUpdater?.refresh()
        walletManager.apiClient?.kv?.syncAllKeys { print("KV finished syncing. err: \(String(describing: $0))") }
        walletManager.apiClient?.updateFeatureFlags()
        if modalPresenter?.walletManager == nil {
            modalPresenter?.walletManager = walletManager
        }
    }

    func retryAfterIsReachable() {
        guard let walletManager = walletManager else { return }
        guard !walletManager.noWallet else { return }
        DispatchQueue.walletQueue.async {
            walletManager.peerManager?.connect()
        }
        exchangeUpdater?.refresh(completion: {})
        feeUpdater?.refresh()
        walletManager.apiClient?.kv?.syncAllKeys { print("KV finished syncing. err: \(String(describing: $0))") }
        walletManager.apiClient?.updateFeatureFlags()
        if modalPresenter?.walletManager == nil {
            modalPresenter?.walletManager = walletManager
        }
    }

    func didEnterBackground() {
        if store.state.walletState.syncState == .success {
            DispatchQueue.walletQueue.async {
                self.walletManager?.peerManager?.disconnect()
            }
        }
        //Save the backgrounding time if the user is logged in
        if !store.state.isLoginRequired {
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: timeSinceLastExitKey)
        }
        walletManager?.apiClient?.kv?.syncAllKeys { print("KV finished syncing. err: \(String(describing: $0))") }
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
        guard let walletManager = walletManager else { assert(false, "WalletManager should exist!"); return }
        guard let rootViewController = window.rootViewController else { return }
        hasPerformedWalletDependentInitialization = true
        store.perform(action: PinLength.set(walletManager.pinLength))
        walletCoordinator = WalletCoordinator(walletManager: walletManager, store: store)
        modalPresenter = ModalPresenter(store: store, walletManager: walletManager, window: window, apiClient: noAuthApiClient, ethStore: ethStore, gethManager: nil, tokenStores: tokenStores)
        exchangeUpdater = ExchangeUpdater(store: store, walletManager: walletManager)
        feeUpdater = FeeUpdater(walletManager: walletManager, store: store)
        startFlowController = StartFlowPresenter(store: store, walletManager: walletManager, rootViewController: rootViewController)
        accountViewController?.walletManager = walletManager
        defaultsUpdater = UserDefaultsUpdater(walletManager: walletManager)
        urlController = URLController(store: self.store, walletManager: walletManager)
        if let url = launchURL {
            _ = urlController?.handleUrl(url)
            launchURL = nil
        }

        if UIApplication.shared.applicationState != .background {
            if walletManager.noWallet {
                UserDefaults.hasShownWelcome = true
                addWalletCreationListener()
                store.perform(action: ShowStartFlow())
            } else {
                modalPresenter?.walletManager = walletManager
                let gethManager = GethManager(ethPrivKey: walletManager.ethPrivKey!, store: store)
                ethWalletCoordinator = EthWalletCoordinator(store: ethStore, gethManager: gethManager, apiClient: noAuthApiClient)
                tokenWalletCoordinators = tokenStores.map { return TokenWalletCoordinator(store: $0, gethManager: gethManager, apiClient: noAuthApiClient) }
                modalPresenter?.gethManager = gethManager
                DispatchQueue.walletQueue.async {
                    walletManager.peerManager?.connect()
                }
                startDataFetchers()
                addNumSentListeners()
            }

        //For when watch app launches app in background
        } else {
            DispatchQueue.walletQueue.async { [weak self] in
                walletManager.peerManager?.connect()
                if self?.fetchCompletionHandler != nil {
                    self?.performBackgroundFetch()
                }
            }
            exchangeUpdater?.refresh(completion: {
                self.watchSessionManager.walletManager = self.walletManager
                self.watchSessionManager.rate = self.store.state.currentRate
            })
        }

    }

    private func addNumSentListeners() {
        let ethLikeStores = [ethStore] + tokenStores
        ethStore.subscribe(self,
                     selector: { $0.walletState.transactions != $1.walletState.transactions },
                     callback: { state in
                        let numSent = state.walletState.transactions.filter { $0.direction == .sent }.count
                        ethLikeStores.forEach { store in
                            store.perform(action: WalletChange.set(store.state.walletState.mutate(numSent: numSent)))
                        }
        })
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
        //Hack to globally hide the back button text
        UIBarButtonItem.appearance().setBackButtonTitlePositionAdjustment(UIOffsetMake(-500.0, -500.0), for: .default)
    }

    private func setupRootViewController() {
        let container = AppContainerViewController()

        let didSelectTransaction: ([Transaction], Int) -> Void = { transactions, selectedIndex in
            guard let kvStore = self.walletManager?.apiClient?.kv else { return }
            let transactionDetails = TransactionDetailsViewController(store: self.store, transactions: transactions, selectedIndex: selectedIndex, kvStore: kvStore)
            transactionDetails.modalPresentationStyle = .overFullScreen
            transactionDetails.transitioningDelegate = self.transitionDelegate
            transactionDetails.modalPresentationCapturesStatusBarAppearance = true
            self.window.rootViewController?.present(transactionDetails, animated: true, completion: nil)
        }
        accountViewController = AccountViewController(store: store, didSelectTransaction: didSelectTransaction)
        accountViewController?.sendCallback = { self.store.perform(action: RootModalActions.Present(modal: .send)) }
        accountViewController?.receiveCallback = { self.store.perform(action: RootModalActions.Present(modal: .receive)) }
        accountViewController?.menuCallback = { self.store.perform(action: RootModalActions.Present(modal: .menu)) }

        ethAccountViewController = AccountViewController(store: ethStore, didSelectTransaction: {_,_ in } )
        ethAccountViewController?.sendCallback = { self.ethStore.perform(action: RootModalActions.Present(modal: .send)) }
        ethAccountViewController?.receiveCallback = { self.ethStore.perform(action: RootModalActions.Present(modal: .receive)) }
        ethAccountViewController?.menuCallback = { self.ethStore.perform(action: RootModalActions.Present(modal: .menu)) }


        let tokenAccountViewControllers: [AccountViewController] = tokenStores.map { store in
            let vc = AccountViewController(store: store, didSelectTransaction: {_,_ in } )
            vc.sendCallback = { store.perform(action: RootModalActions.Present(modal: .send)) }
            vc.receiveCallback = { store.perform(action: RootModalActions.Present(modal: .receive)) }
            vc.menuCallback = { store.perform(action: RootModalActions.Present(modal: .menu)) }
            return vc
        }

        accountViewControllers = [accountViewController!, ethAccountViewController!] + tokenAccountViewControllers

        container.child = accountViewController
        container.addChildViewController(accountViewController!, layout: {
            accountViewController!.view.constrain(toSuperviewEdges: nil)
        })
        containerViewController = container
        window.rootViewController = container

        NotificationCenter.default.addObserver(forName: .SwitchCurrencyNotification, object: nil, queue: nil, using: { note in
            if let info = note.userInfo {
                if let currency = info["currency"] as? String {
                    if currency == "btc" {
                        self.switchToAccount(vc: self.accountViewController!)
                    } else if currency == "eth" {
                        self.switchToAccount(vc: self.ethAccountViewController!)
                    } else {
                        let vc = self.accountViewControllers?.filter{ $0.tokenSymbol == currency }
                        self.switchToAccount(vc: vc!.first!)
                    }
                }
            }
        })
    }

    private func switchToAccount(vc: AccountViewController) {
        guard containerViewController?.child != vc else { return }
        guard let accountViewControllers = accountViewControllers else { return }
        accountViewControllers.filter { $0 != vc }.forEach {
            $0.removeFromParentViewController()
        }
        containerViewController?.child = vc
        containerViewController?.addChildViewController(vc, layout: {
            vc.view.constrain(toSuperviewEdges: nil)
        })
    }

    private func startDataFetchers() {
        walletManager?.apiClient?.updateFeatureFlags()
        initKVStoreCoordinator()
        feeUpdater?.refresh()
        defaultsUpdater?.refresh()
        walletManager?.apiClient?.events?.up()
        exchangeUpdater?.refresh(completion: {
            self.watchSessionManager.walletManager = self.walletManager
            self.watchSessionManager.rate = self.store.state.currentRate
        })
    }

    private func addWalletCreationListener() {
        store.subscribe(self, name: .didCreateOrRecoverWallet, callback: { _ in
            guard let walletManager = self.walletManager else { return }
            self.modalPresenter?.walletManager = self.walletManager
            self.startDataFetchers()
            let gethManager = GethManager(ethPrivKey: walletManager.ethPrivKey!, store: self.store)
            self.modalPresenter?.gethManager = gethManager
            self.ethWalletCoordinator = EthWalletCoordinator(store: self.ethStore, gethManager: gethManager, apiClient: self.noAuthApiClient)
            self.tokenWalletCoordinators = self.tokenStores.map { return TokenWalletCoordinator(store: $0, gethManager: gethManager, apiClient: self.noAuthApiClient) }
            self.addNumSentListeners()
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
        guard let kvStore = walletManager?.apiClient?.kv else { return }
        guard kvStoreCoordinator == nil else { return }
        kvStore.syncAllKeys { error in
            print("KV finished syncing. err: \(String(describing: error))")
            self.walletCoordinator?.kvStore = kvStore
            self.kvStoreCoordinator = KVStoreCoordinator(store: self.store, kvStore: kvStore)
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
                    store.trigger(name: .openFile(file))
                }
            } catch let error {
                print("Could not open file at: \(url), error: \(error)")
            }
        }
    }

    func performBackgroundFetch() {
        saveEvent("appController.performBackgroundFetch")
        let group = DispatchGroup()
        if let peerManager = walletManager?.peerManager, peerManager.syncProgress(fromStartHeight: peerManager.lastBlockHeight) < 1.0 {
            group.enter()
            store.lazySubscribe(self, selector: { $0.walletState.syncState != $1.walletState.syncState }, callback: { state in
                if self.fetchCompletionHandler != nil {
                    if state.walletState.syncState == .success {
                        DispatchQueue.walletQueue.async {
                            peerManager.disconnect()
                            group.leave()
                        }
                    }
                }
            })
        }

        group.enter()
        Async.parallel(callbacks: [
            { self.exchangeUpdater?.refresh(completion: $0) },
            { self.feeUpdater?.refresh(completion: $0) },
            { self.walletManager?.apiClient?.events?.sync(completion: $0) },
            { self.walletManager?.apiClient?.updateFeatureFlags(); $0() }
            ], completion: {
                group.leave()
        })

        DispatchQueue.global(qos: .utility).async {
            if group.wait(timeout: .now() + 25.0) == .timedOut {
                self.saveEvent("appController.backgroundFetchFailed")
                self.fetchCompletionHandler?(.failed)
            } else {
                self.saveEvent("appController.backgroundFetchNewData")
                self.fetchCompletionHandler?(.newData)
            }
            self.fetchCompletionHandler = nil
        }
    }

    func willResignActive() {
        guard !store.state.isPushNotificationsEnabled else { return }
        guard let pushToken = UserDefaults.pushToken else { return }
        walletManager?.apiClient?.deletePushNotificationToken(pushToken)
    }
}

//MARK: - Push notifications
extension ApplicationController {
    func listenForPushNotificationRequest() {
        store.subscribe(self, name: .registerForPushNotificationToken, callback: { _ in 
            let settings = UIUserNotificationSettings(types: [.badge, .sound, .alert], categories: nil)
            self.application?.registerUserNotificationSettings(settings)
        })
    }

    func application(_ application: UIApplication, didRegister notificationSettings: UIUserNotificationSettings) {
        if !notificationSettings.types.isEmpty {
            application.registerForRemoteNotifications()
        }
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        guard let apiClient = walletManager?.apiClient else { return }
        guard UserDefaults.pushToken != deviceToken else { return }
        UserDefaults.pushToken = deviceToken
        apiClient.savePushNotificationToken(deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("didFailToRegisterForRemoteNotification: \(error)")
    }
}

let tst = Token(name: "Test Standard Token",
                code: "TST",
                 symbol: "t$",
                 address: "0x722dd3F80BAC40c951b51BdD28Dd19d435762180",
                 decimals: 18,
                 abi: "[{\"constant\":true,\"inputs\":[],\"name\":\"name\",\"outputs\":[{\"name\":\"\",\"type\":\"string\"}],\"payable\":false,\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"_spender\",\"type\":\"address\"},{\"name\":\"_value\",\"type\":\"uint256\"}],\"name\":\"approve\",\"outputs\":[{\"name\":\"success\",\"type\":\"bool\"}],\"payable\":false,\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"totalSupply\",\"outputs\":[{\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"_from\",\"type\":\"address\"},{\"name\":\"_to\",\"type\":\"address\"},{\"name\":\"_value\",\"type\":\"uint256\"}],\"name\":\"transferFrom\",\"outputs\":[{\"name\":\"success\",\"type\":\"bool\"}],\"payable\":false,\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"decimals\",\"outputs\":[{\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"name\":\"_owner\",\"type\":\"address\"}],\"name\":\"balanceOf\",\"outputs\":[{\"name\":\"balance\",\"type\":\"uint256\"}],\"payable\":false,\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"symbol\",\"outputs\":[{\"name\":\"\",\"type\":\"string\"}],\"payable\":false,\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"_to\",\"type\":\"address\"},{\"name\":\"_value\",\"type\":\"uint256\"}],\"name\":\"showMeTheMoney\",\"outputs\":[],\"payable\":false,\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"_to\",\"type\":\"address\"},{\"name\":\"_value\",\"type\":\"uint256\"}],\"name\":\"transfer\",\"outputs\":[{\"name\":\"success\",\"type\":\"bool\"}],\"payable\":false,\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"name\":\"_owner\",\"type\":\"address\"},{\"name\":\"_spender\",\"type\":\"address\"}],\"name\":\"allowance\",\"outputs\":[{\"name\":\"remaining\",\"type\":\"uint256\"}],\"payable\":false,\"type\":\"function\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"name\":\"_from\",\"type\":\"address\"},{\"indexed\":true,\"name\":\"_to\",\"type\":\"address\"},{\"indexed\":false,\"name\":\"_value\",\"type\":\"uint256\"}],\"name\":\"Transfer\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"name\":\"_owner\",\"type\":\"address\"},{\"indexed\":true,\"name\":\"_spender\",\"type\":\"address\"},{\"indexed\":false,\"name\":\"_value\",\"type\":\"uint256\"}],\"name\":\"Approval\",\"type\":\"event\"}]")

let xjp = Token(name: "XJP Token",
                code: "XJP",
                symbol: "x¥",
                address: "0x39689fE671C01fcE173395f6BC45D4C332026666",
                decimals: 0,
                abi: "[{\"constant\":true,\"inputs\":[],\"name\":\"name\",\"outputs\":[{\"name\":\"\",\"type\":\"string\"}],\"payable\":false,\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"_spender\",\"type\":\"address\"},{\"name\":\"_value\",\"type\":\"uint256\"}],\"name\":\"approve\",\"outputs\":[{\"name\":\"success\",\"type\":\"bool\"}],\"payable\":false,\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"totalSupply\",\"outputs\":[{\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"_from\",\"type\":\"address\"},{\"name\":\"_to\",\"type\":\"address\"},{\"name\":\"_value\",\"type\":\"uint256\"}],\"name\":\"transferFrom\",\"outputs\":[{\"name\":\"success\",\"type\":\"bool\"}],\"payable\":false,\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"decimals\",\"outputs\":[{\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"name\":\"_owner\",\"type\":\"address\"}],\"name\":\"balanceOf\",\"outputs\":[{\"name\":\"balance\",\"type\":\"uint256\"}],\"payable\":false,\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"symbol\",\"outputs\":[{\"name\":\"\",\"type\":\"string\"}],\"payable\":false,\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"_to\",\"type\":\"address\"},{\"name\":\"_value\",\"type\":\"uint256\"}],\"name\":\"showMeTheMoney\",\"outputs\":[],\"payable\":false,\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"_to\",\"type\":\"address\"},{\"name\":\"_value\",\"type\":\"uint256\"}],\"name\":\"transfer\",\"outputs\":[{\"name\":\"success\",\"type\":\"bool\"}],\"payable\":false,\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"name\":\"_owner\",\"type\":\"address\"},{\"name\":\"_spender\",\"type\":\"address\"}],\"name\":\"allowance\",\"outputs\":[{\"name\":\"remaining\",\"type\":\"uint256\"}],\"payable\":false,\"type\":\"function\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"name\":\"_from\",\"type\":\"address\"},{\"indexed\":true,\"name\":\"_to\",\"type\":\"address\"},{\"indexed\":false,\"name\":\"_value\",\"type\":\"uint256\"}],\"name\":\"Transfer\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"name\":\"_owner\",\"type\":\"address\"},{\"indexed\":true,\"name\":\"_spender\",\"type\":\"address\"},{\"indexed\":false,\"name\":\"_value\",\"type\":\"uint256\"}],\"name\":\"Approval\",\"type\":\"event\"}]")
