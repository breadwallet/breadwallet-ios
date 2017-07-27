//
//  ApplicationController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-21.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

private let timeSinceLastExitKey = "TimeSinceLastExit"
private let shouldRequireLoginTimeoutKey = "ShouldRequireLoginTimeoutKey"

class ApplicationController : Subscriber {

    //Ideally the window would be private, but is unfortunately required
    //by the UIApplicationDelegate Protocol
    let window = UIWindow()
    fileprivate let store = Store()
    private var startFlowController: StartFlowPresenter?
    private var modalPresenter: ModalPresenter?

    fileprivate var walletManager: WalletManager?
    private var walletCoordinator: WalletCoordinator?
    private var exchangeUpdater: ExchangeUpdater?
    private var feeUpdater: FeeUpdater?
    private let transitionDelegate: ModalTransitionDelegate
    private var kvStoreCoordinator: KVStoreCoordinator?
    private var accountViewController: AccountViewController?
    fileprivate var application: UIApplication?
    private let watchSessionManager = PhoneWCSessionManager()
    private var urlController: URLController?
    private var defaultsUpdater: UserDefaultsUpdater?
    private var reachability = ReachabilityManager(host: "google.com")
    private let noAuthApiClient = BRAPIClient(authenticator: NoAuthAuthenticator())

    init() {
        transitionDelegate = ModalTransitionDelegate(type: .transactionDetail, store: store)
        DispatchQueue.walletQueue.async {
            guardProtected {
                self.initWallet()
            }
        }
    }

    private func initWallet() {
        self.walletManager = try? WalletManager(store: self.store, dbPath: nil)
        let _ = self.walletManager?.wallet //attempt to initialize wallet
        DispatchQueue.main.async {
            self.didInitWallet()
        }
    }

    func launch(application: UIApplication, options: [UIApplicationLaunchOptionsKey: Any]?) {
        self.application = application
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
                            self.didInitWallet()
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
        //Save the backgrounding time if the user is logged in
        //TODO - fix this
        if !store.state.isLoginRequired {
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: timeSinceLastExitKey)
        }
        walletManager?.apiClient?.kv?.syncAllKeys { print("KV finished syncing. err: \(String(describing: $0))") }
    }

    func performFetch(_ completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        Async.parallel(callbacks: [
                { completion in
                    self.exchangeUpdater?.refresh(completion: completion)
                },
                { completion in
                    self.feeUpdater?.refresh(completion: completion)
                },
                { completion in
                    self.walletManager?.apiClient?.events?.sync(completion: completion)
                },
                { completion in
                    self.walletManager?.apiClient?.updateFeatureFlags()
                    completion()
                }
            ], completion: {
                completionHandler(.newData) //TODO - add a timeout for this
        })
    }

    func open(url: URL) -> Bool {
        return urlController?.handleUrl(url) ?? false
    }

    private func didInitWallet() {
        guard let walletManager = walletManager else { assert(false, "WalletManager should exist!"); return }
        store.perform(action: PinLength.set(walletManager.pinLength))
        walletCoordinator = WalletCoordinator(walletManager: walletManager, store: store)
        modalPresenter = ModalPresenter(store: store, walletManager: walletManager, window: window, apiClient: noAuthApiClient)
        exchangeUpdater = ExchangeUpdater(store: store, walletManager: walletManager)
        feeUpdater = FeeUpdater(walletManager: walletManager, store: store)
        startFlowController = StartFlowPresenter(store: store, walletManager: walletManager, rootViewController: window.rootViewController!)
        accountViewController?.walletManager = walletManager
        defaultsUpdater = UserDefaultsUpdater(walletManager: walletManager)
        urlController = URLController(store: self.store, walletManager: walletManager)

        if UIApplication.shared.applicationState != .background {
            if walletManager.noWallet {
                addWalletCreationListener()
                store.perform(action: ShowStartFlow())
            } else {
                modalPresenter?.walletManager = walletManager
                DispatchQueue.walletQueue.async {
                    walletManager.peerManager?.connect()
                }
                self.startDataFetchers()
            }

        //For when watch app launches app in background
        } else {
            DispatchQueue.walletQueue.async {
                walletManager.peerManager?.connect()
            }
            exchangeUpdater?.refresh(completion: {
                self.watchSessionManager.walletManager = self.walletManager
                self.watchSessionManager.rate = self.store.state.currentRate
            })
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
        UINavigationBar.appearance().titleTextAttributes = [NSFontAttributeName: UIFont.header]
        //Hack to globally hide the back button text
        UIBarButtonItem.appearance().setBackButtonTitlePositionAdjustment(UIOffsetMake(-500.0, -500.0), for: .default)
    }

    private func setupRootViewController() {
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
        window.rootViewController = accountViewController
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
            self.modalPresenter?.walletManager = self.walletManager
            self.startDataFetchers()
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
