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

    //Ideally the window would be private, but is unfortunately required
    //by the UIApplicationDelegate Protocol
    let window = UIWindow()
    private var startFlowController: StartFlowPresenter?
    private var modalPresenter: ModalPresenter?

    private var walletManagers = [WalletManager]()
    private var walletCoordinators = [WalletCoordinator]()
    private var exchangeUpdaters = [ExchangeUpdater]()
    private var feeUpdater: FeeUpdater?
    private var kvStoreCoordinator: KVStoreCoordinator?
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

    // MARK: -

    init() {
        DispatchQueue.walletQueue.async {
            guardProtected(queue: DispatchQueue.walletQueue) {
                self.initWallet()
            }
        }
    }

    private func initWallet() {
        let dispatchGroup = DispatchGroup()
        Store.state.currencies.forEach { currency in
            dispatchGroup.enter()
            guard let currency = currency as? Bitcoin else { return }
            guard let walletManager = try? WalletManager(currency: currency, dbPath: currency.dbPath) else { return }
            walletCoordinators.append(WalletCoordinator(walletManager: walletManager, currency: currency))
            exchangeUpdaters.append(ExchangeUpdater(currency: currency, walletManager: walletManager))
            walletManagers.append(walletManager)
            walletManager.initWallet { success in
                walletManager.initPeerManager {
                    dispatchGroup.leave()
                }
            }
        }
        dispatchGroup.notify(queue: .main) {
            self.didAttemptInitWallet()
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
        Store.subscribe(self, name: .reinitWalletManager(nil), callback: {
            guard let trigger = $0 else { return }
            if case .reinitWalletManager(let callback) = trigger {
                if let callback = callback {
                    Store.removeAllSubscriptions()
                    Store.perform(action: Reset())
                    self.setup()
                    DispatchQueue.walletQueue.async {
                        //TODO:BCH - reinit walletmanagers
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
        let walletManager = walletManagers[0]
        guard !walletManager.noWallet else { return }
        if shouldRequireLogin() {
            Store.perform(action: RequireLogin())
        }
        DispatchQueue.walletQueue.async {
            walletManager.peerManager?.connect()
        }
        exchangeUpdaters.forEach { $0.refresh(completion: {}) }
        feeUpdater?.refresh()
        walletManager.apiClient?.kv?.syncAllKeys { print("KV finished syncing. err: \(String(describing: $0))") }
        walletManager.apiClient?.updateFeatureFlags()
        if modalPresenter?.walletManager == nil {
            modalPresenter?.walletManager = walletManager
        }
    }

    func retryAfterIsReachable() {
        let walletManager = walletManagers[0]
        guard !walletManager.noWallet else { return }
        DispatchQueue.walletQueue.async {
            walletManager.peerManager?.connect()
        }
        exchangeUpdaters.forEach { $0.refresh(completion: {}) }
        feeUpdater?.refresh()
        walletManager.apiClient?.kv?.syncAllKeys { print("KV finished syncing. err: \(String(describing: $0))") }
        walletManager.apiClient?.updateFeatureFlags()
        if modalPresenter?.walletManager == nil {
            modalPresenter?.walletManager = walletManager
        }
    }

    func didEnterBackground() {
        // TODO:BCH - disconnect synced peer managers
        //Save the backgrounding time if the user is logged in
        if !Store.state.isLoginRequired {
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: timeSinceLastExitKey)
        }
        walletManagers[0].apiClient?.kv?.syncAllKeys { print("KV finished syncing. err: \(String(describing: $0))") }
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
        let walletManager = walletManagers[0]
        guard let rootViewController = window.rootViewController as? RootNavigationController else { return }
        Store.perform(action: PinLength.set(walletManager.pinLength))
        rootViewController.walletManager = walletManager
        hasPerformedWalletDependentInitialization = true
        modalPresenter = ModalPresenter(walletManager: walletManager, window: window, apiClient: noAuthApiClient, gethManager: nil)
        feeUpdater = FeeUpdater(walletManager: walletManager)
        startFlowController = StartFlowPresenter(walletManager: walletManager, rootViewController: rootViewController)

        defaultsUpdater = UserDefaultsUpdater(walletManager: walletManager)
        urlController = URLController(walletManager: walletManager)
        if let url = launchURL {
            _ = urlController?.handleUrl(url)
            launchURL = nil
        }

        if UIApplication.shared.applicationState != .background {
            if walletManager.noWallet {
                UserDefaults.hasShownWelcome = true
                addWalletCreationListener()
                Store.perform(action: ShowStartFlow())
            } else {
                modalPresenter?.walletManager = walletManager
                let gethManager = GethManager(ethPubKey: walletManager.ethPubKey!)
                modalPresenter?.gethManager = gethManager
                DispatchQueue.walletQueue.async { [weak self] in
                    self?.walletManagers.forEach { $0.peerManager?.connect() }
                }
                startDataFetchers()
            }

        //For when watch app launches app in background
        } else {
            DispatchQueue.walletQueue.async { [weak self] in
                walletManager.peerManager?.connect()
                if self?.fetchCompletionHandler != nil {
                    self?.performBackgroundFetch()
                }
            }
            exchangeUpdaters.forEach {
                $0.refresh(completion: {
                    self.watchSessionManager.walletManager = self.walletManagers[0]
                    self.watchSessionManager.rate = Currencies.btc.state.currentRate
                })
            }
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
        let home = HomeScreenViewController()
        let nc = RootNavigationController()
        nc.navigationBar.isTranslucent = false
        nc.navigationBar.tintColor = .white
        nc.pushViewController(home, animated: false)
        home.didSelectCurrency = { currency in
            //guard let accountViewController = self.accountViewControllers[currency.code] else { return }
            let accountViewController = AccountViewController(currency: currency)
            accountViewController.walletManager = self.walletManagers[0]
            nc.pushViewController(accountViewController, animated: true)
        }
        
        //accountViewControllers = Dictionary(uniqueKeysWithValues: Store.state.currencies.map { ($0.code, AccountViewController(currency: $0)) })
        window.rootViewController = nc
    }

    private func startDataFetchers() {
//        walletManager?.apiClient?.updateFeatureFlags()
//        initKVStoreCoordinator()
//        feeUpdater?.refresh()
//        defaultsUpdater?.refresh()
//        walletManager?.apiClient?.events?.up()
        exchangeUpdaters.forEach {
            $0.refresh(completion: {
                //self.watchSessionManager.walletManager = self.walletManager
                self.watchSessionManager.rate = Currencies.btc.state.currentRate
            })
        }
    }

    private func addWalletCreationListener() {
//        Store.subscribe(self, name: .didCreateOrRecoverWallet, callback: { _ in
//            DispatchQueue.walletQueue.async {
//                self.walletManager?.initWallet { _ in
//                    self.walletManager?.initPeerManager {
//                        self.walletManager?.peerManager?.connect()
//                        self.modalPresenter?.walletManager = self.walletManager
//                        self.startDataFetchers()
//
//                    }
//                }
//            }
//        })
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
//        guard let kvStore = walletManager?.apiClient?.kv else { return }
//        guard kvStoreCoordinator == nil else { return }
//        kvStore.syncAllKeys { error in
//            print("KV finished syncing. err: \(String(describing: error))")
//            self.walletCoordinator?.kvStore = kvStore
//            self.kvStoreCoordinator = KVStoreCoordinator(kvStore: kvStore)
//            self.kvStoreCoordinator?.retreiveStoredWalletInfo()
//            self.kvStoreCoordinator?.listenForWalletChanges()
//        }
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
        guard !Store.state.isPushNotificationsEnabled else { return }
        guard let pushToken = UserDefaults.pushToken else { return }
        //walletManager?.apiClient?.deletePushNotificationToken(pushToken)
    }
}

//MARK: - Push notifications
extension ApplicationController {
    func listenForPushNotificationRequest() {
        Store.subscribe(self, name: .registerForPushNotificationToken, callback: { _ in
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
//        guard let apiClient = walletManager?.apiClient else { return }
//        guard UserDefaults.pushToken != deviceToken else { return }
//        UserDefaults.pushToken = deviceToken
//        apiClient.savePushNotificationToken(deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("didFailToRegisterForRemoteNotification: \(error)")
    }
}
