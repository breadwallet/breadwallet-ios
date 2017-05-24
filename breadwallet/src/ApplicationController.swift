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

class ApplicationController : EventManagerCoordinator, Subscriber {

    //Ideally the window would be private, but is unfortunately required
    //by the UIApplicationDelegate Protocol
    let window = UIWindow()
    fileprivate let store = Store()
    private var startFlowController: StartFlowPresenter?
    private var modalPresenter: ModalPresenter?

    private var walletManager: WalletManager?
    private var walletCreator: WalletCreator?
    private var walletCoordinator: WalletCoordinator?
    fileprivate var apiClient: BRAPIClient?
    private var exchangeUpdater: ExchangeUpdater?
    private var feeUpdater: FeeUpdater?
    private let transitionDelegate = ModalTransitionDelegate(type: .transactionDetail)
    private var kvStoreCoordinator: KVStoreCoordinator?
    private var accountViewController: AccountViewController?
    fileprivate var application: UIApplication?
    private let watchSessionManager = PhoneWCSessionManager()
    
    init() {
        DispatchQueue.walletQueue.async {
            self.walletManager = try! WalletManager(dbPath: nil)
            DispatchQueue.main.async {
                self.didInitWallet()
            }
        }
    }

    func launch(application: UIApplication, options: [UIApplicationLaunchOptionsKey: Any]?) {
        self.application = application
        setupDefaults()
        setupAppearance()
        setupRootViewController()
        window.makeKeyAndVisible()
        startEventManager()
        updateAssetBundles()
        listenForPushNotificationRequest()
        offMainInitialization()
        handleLaunchOptions(options)
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
        apiClient?.kv?.syncAllKeys { print("KV finished syncing. err: \(String(describing: $0))") }
        apiClient?.updateFeatureFlags()
    }

    func didEnterBackground() {
        //Save the backgrounding time if the user is logged in
        //TODO - fix this
        if !store.state.isLoginRequired {
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: timeSinceLastExitKey)
        }
        apiClient?.kv?.syncAllKeys { print("KV finished syncing. err: \(String(describing: $0))") }
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
                    self.syncEventManager(completion: completion)
                },
                { completion in
                    self.apiClient?.updateFeatureFlags()
                    completion()
                }
            ], completion: {
                completionHandler(.newData) //TODO - add a timeout for this
        })
    }

    private func didInitWallet() {
        guard let walletManager = walletManager else { assert(false, "WalletManager should exist!"); return }
        walletCreator = WalletCreator(walletManager: walletManager, store: store)
        walletCoordinator = WalletCoordinator(walletManager: walletManager, store: store)
        apiClient = BRAPIClient(authenticator: walletManager)
        modalPresenter = ModalPresenter(store: store, apiClient: apiClient!, window: window)
        exchangeUpdater = ExchangeUpdater(store: store, apiClient: apiClient!)
        feeUpdater = FeeUpdater(walletManager: walletManager, apiClient: apiClient!)
        startFlowController = StartFlowPresenter(store: store, walletManager: walletManager, rootViewController: window.rootViewController!)
        accountViewController?.walletManager = walletManager

        if UIApplication.shared.applicationState != .background {
            if walletManager.noWallet {
                addWalletCreationListener()
                store.perform(action: ShowStartFlow())
            } else {
                modalPresenter?.walletManager = walletManager
                DispatchQueue.walletQueue.async {
                    walletManager.peerManager?.connect()
                }
                feeUpdater?.updateWalletFees()
                apiClient?.updateFeatureFlags()
                initKVStoreCoordinator()
            }
            exchangeUpdater?.refresh(completion: {
                self.watchSessionManager.walletManager = self.walletManager
                self.watchSessionManager.rate = self.store.state.currentRate
            })
            feeUpdater?.refresh()
            updateAssetBundles()

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
            guard let kvStore = self.apiClient?.kv else { return }
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

    private func addWalletCreationListener() {
        store.subscribe(self,
                        selector: { $0.pinCreationStep != $1.pinCreationStep || $0.alert != $1.alert },
                        callback: {

                            //TODO - figure out a better way to do this..should use a trigger instead
                            var shouldLoadWallet = false
                            if case .saveSuccess = $0.pinCreationStep {
                                shouldLoadWallet = true
                            }
                            if let alert = $0.alert {
                                if alert == .pinSet {
                                    shouldLoadWallet = true
                                }
                            }
                            if shouldLoadWallet {
                                self.modalPresenter?.walletManager = self.walletManager
                                self.feeUpdater?.updateWalletFees()
                                self.feeUpdater?.refresh()
                                self.initKVStoreCoordinator()
                                self.apiClient?.updateFeatureFlags()
                            }

        })
    }
    
    private func updateAssetBundles() {
        apiClient?.updateBundles { errors in
            for (n, e) in errors {
                print("Bundle \(n) ran update. err: \(String(describing: e))")
            }
        }
    }

    private func initKVStoreCoordinator() {
        guard let kvStore = apiClient?.kv else { return }
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
        guard let apiClient = self.apiClient else { return }
        apiClient.savePushNotificationToken(deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("didFailToRegisterForRemoteNotification: \(error)")
    }
}
