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
        transitionDelegate = ModalTransitionDelegate(type: .transactionDetail)
        DispatchQueue.walletQueue.async {
            guardProtected(queue: DispatchQueue.walletQueue) {
                self.initWallet()
            }
        }
        self.setColors()
    }

    private func initWallet() {
        walletManager = try? WalletManager(dbPath: nil)
        walletManager?.initWallet { success in
            if success {
                self.walletManager?.initPeerManager {
                    self.didAttemptInitWallet()
                }
            } else {
                self.didAttemptInitWallet()
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
                        do {
                            self.walletManager = try WalletManager(dbPath: nil)
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
            Store.perform(action: RequireLogin())
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
        if Store.state.walletState.syncState == .success {
            DispatchQueue.walletQueue.async {
                self.walletManager?.peerManager?.disconnect()
            }
        }
        //Save the backgrounding time if the user is logged in
        if !Store.state.isLoginRequired {
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
        guard let rootViewController = window.rootViewController as? RootNavigationController else { return }
        Store.perform(action: PinLength.set(walletManager.pinLength))
        rootViewController.walletManager = walletManager
        hasPerformedWalletDependentInitialization = true
        walletCoordinator = WalletCoordinator(walletManager: walletManager)
        modalPresenter = ModalPresenter(walletManager: walletManager, window: window, apiClient: noAuthApiClient, gethManager: nil)
        exchangeUpdater = ExchangeUpdater(walletManager: walletManager)
        feeUpdater = FeeUpdater(walletManager: walletManager)
        startFlowController = StartFlowPresenter(walletManager: walletManager, rootViewController: rootViewController)
        accountViewController?.walletManager = walletManager

        accountViewControllers?.forEach {
            $0.walletManager = walletManager
        }

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
                DispatchQueue.walletQueue.async {
                    walletManager.peerManager?.connect()
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
            exchangeUpdater?.refresh(completion: {
                self.watchSessionManager.walletManager = self.walletManager
                self.watchSessionManager.rate = Store.state.currentRate
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
        UINavigationBar.appearance().titleTextAttributes = [NSAttributedStringKey.font: UIFont.header]
    }

    private func setupRootViewController() {
        let home = HomeScreenViewController()
        let nc = RootNavigationController()
        nc.navigationBar.isTranslucent = false
        nc.navigationBar.tintColor = .white
        nc.pushViewController(home, animated: false)
        home.didSelectCurrency = { [weak self] currency in
            nc.pushViewController(self!.accountViewController!, animated: true)
        }

        window.rootViewController = nc

        let didSelectTransaction: ([Transaction], Int) -> Void = { transactions, selectedIndex in
            let transactionDetails = TransactionDetailsViewController(transactions: transactions, selectedIndex: selectedIndex)
            transactionDetails.modalPresentationStyle = .overFullScreen
            transactionDetails.transitioningDelegate = self.transitionDelegate
            transactionDetails.modalPresentationCapturesStatusBarAppearance = true
            self.window.rootViewController?.present(transactionDetails, animated: true, completion: nil)
        }

        let didSelectEthTransaction: ([Transaction], Int) -> Void = { transactions, selectedIndex in
            let transactionDetails = TransactionDetailsViewController(transactions: transactions, selectedIndex: selectedIndex)
            transactionDetails.modalPresentationStyle = .overFullScreen
            transactionDetails.transitioningDelegate = self.transitionDelegate
            transactionDetails.modalPresentationCapturesStatusBarAppearance = true
            self.window.rootViewController?.present(transactionDetails, animated: true, completion: nil)
        }

        accountViewController = AccountViewController(didSelectTransaction: didSelectTransaction)
        accountViewControllers = [accountViewController!, accountViewController!]
    }

    private func startDataFetchers() {
        walletManager?.apiClient?.updateFeatureFlags()
        initKVStoreCoordinator()
        feeUpdater?.refresh()
        defaultsUpdater?.refresh()
        walletManager?.apiClient?.events?.up()
        exchangeUpdater?.refresh(completion: {
            self.watchSessionManager.walletManager = self.walletManager
            self.watchSessionManager.rate = Store.state.currentRate
        })
    }

    private func addWalletCreationListener() {
        Store.subscribe(self, name: .didCreateOrRecoverWallet, callback: { _ in
            DispatchQueue.walletQueue.async {
                self.walletManager?.initWallet { _ in
                    self.walletManager?.initPeerManager {
                        self.walletManager?.peerManager?.connect()
                        self.modalPresenter?.walletManager = self.walletManager
                        self.startDataFetchers()

                    }
                }
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
        guard let kvStore = walletManager?.apiClient?.kv else { return }
        guard kvStoreCoordinator == nil else { return }
        kvStore.syncAllKeys { error in
            print("KV finished syncing. err: \(String(describing: error))")
            self.walletCoordinator?.kvStore = kvStore
            self.kvStoreCoordinator = KVStoreCoordinator(kvStore: kvStore)
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
        guard !Store.state.isPushNotificationsEnabled else { return }
        guard let pushToken = UserDefaults.pushToken else { return }
        walletManager?.apiClient?.deletePushNotificationToken(pushToken)
    }

    private func setColors() {
        Store.perform(action: StateChange(Store.state.mutate(colours: (UIColor(red:0.972549, green:0.623529, blue:0.200000, alpha:1.0), UIColor(red:0.898039, green:0.505882, blue:0.031373, alpha:1.0)))))
//        ethStore.perform(action: StateChange(ethStore.state.mutate(colours: (UIColor(red:0.407843, green:0.529412, blue:0.654902, alpha:1.0), UIColor(red:0.180392, green:0.278431, blue:0.376471, alpha:1.0)))))
//        tokenStores.forEach {
//            if $0.state.walletState.crowdsale != nil {
//                $0.perform(action: StateChange($0.state.mutate(colours: (UIColor(red:0.976471, green:0.647059, blue:0.219608, alpha:1.0), UIColor(red:1.000000, green:0.309804, blue:0.580392, alpha:1.0)))))
//            } else {
//                $0.perform(action: StateChange($0.state.mutate(colours: (UIColor(red:0.95, green:0.65, blue:0.00, alpha:1.0), UIColor(red:0.95, green:0.35, blue:0.13, alpha:1.0)))))
//            }
//        }
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
        guard let apiClient = walletManager?.apiClient else { return }
        guard UserDefaults.pushToken != deviceToken else { return }
        UserDefaults.pushToken = deviceToken
        apiClient.savePushNotificationToken(deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("didFailToRegisterForRemoteNotification: \(error)")
    }
}
