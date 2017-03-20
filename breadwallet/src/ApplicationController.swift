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
    private let store = Store()
    private var startFlowController: StartFlowPresenter?
    private var modalPresenter: ModalPresenter?

    private var walletManager: WalletManager?
    private var walletCreator: WalletCreator?
    private var walletCoordinator: WalletCoordinator?
    private var apiClient: BRAPIClient?
    private var exchangeUpdater: ExchangeUpdater?
    private var feeUpdater: FeeUpdater?
    private let transitionDelegate: ModalTransitionDelegate
    private var kvStoreCoordinator: KVStoreCoordinator?

    init() {
        transitionDelegate = ModalTransitionDelegate(store: store, type: .transactionDetail)
        DispatchQueue(label: C.walletQueue).async {
            self.walletManager = try! WalletManager(dbPath: nil)
            DispatchQueue.main.async {
                self.didInitWallet()
            }
        }
    }

    func launch(options: [UIApplicationLaunchOptionsKey: Any]?) {
        setupDefaults()
        setupAppearance()
        setupRootViewController()
        setupPresenters()
        window.makeKeyAndVisible()
        startEventManager()
    }

    func willEnterForeground() {
        guard let walletManager = walletManager else { return }
        guard !walletManager.noWallet else { return }
        if shouldRequireLogin() {
            store.perform(action: RequireLogin())
        }
        DispatchQueue(label: C.walletQueue).async {
            walletManager.peerManager?.connect()
        }
        exchangeUpdater?.refresh()
        feeUpdater?.refresh()
        if let kvStore = apiClient?.kv {
            kvStore.sync { print("KV finished syncing. err: \($0)") }
        }
    }

    func didEnterBackground() {
        //Save the backgrounding time if the user is logged in
        if !store.state.isLoginRequired {
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: timeSinceLastExitKey)
        }
        if let kvStore = apiClient?.kv {
            kvStore.sync { print("KV finished syncing. err: \($0)") }
        }
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
            ], completion: {
                completionHandler(.newData) //TODO - add a timeout for this
        })
    }

    private func didInitWallet() {
        guard let walletManager = walletManager else { assert(false, "WalletManager should exist!"); return }
        walletCreator = WalletCreator(walletManager: walletManager, store: store)
        walletCoordinator = WalletCoordinator(walletManager: walletManager, store: store)
        apiClient = BRAPIClient(authenticator: walletManager)
        exchangeUpdater = ExchangeUpdater(store: store, apiClient: apiClient!)
        feeUpdater = FeeUpdater(walletManager: walletManager, apiClient: apiClient!)
        startFlowController = StartFlowPresenter(store: store, walletManager: walletManager, rootViewController: window.rootViewController!)

        if UIApplication.shared.applicationState != .background {
            if walletManager.noWallet {
                addWalletCreationListener()
                store.perform(action: ShowStartFlow())
            } else {
                initKVStoreCoordinator()
                if shouldRequireLogin() {
                    store.perform(action: RequireLogin())
                }
                modalPresenter?.walletManager = walletManager
                DispatchQueue(label: C.walletQueue).async {
                    walletManager.peerManager?.connect()
                }
                feeUpdater?.updateWalletFees()
            }
            exchangeUpdater?.refresh()
            feeUpdater?.refresh()
            if let kvStore = apiClient?.kv {
                kvStore.sync { print("KV finished syncing. err: \($0)") }
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
        window.tintColor = .brand
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
        let accountViewController = AccountViewController(store: store, didSelectTransaction: didSelectTransaction)
        accountViewController.sendCallback = { self.store.perform(action: RootModalActions.Present(modal: .send)) }
        accountViewController.receiveCallback = { self.store.perform(action: RootModalActions.Present(modal: .receive)) }
        accountViewController.menuCallback = { self.store.perform(action: RootModalActions.Present(modal: .menu)) }
        window.rootViewController = accountViewController
    }

    private func setupPresenters() {
        modalPresenter = ModalPresenter(store: store, window: window)
    }

    private func addWalletCreationListener() {
        store.subscribe(self,
                        selector: { $0.pinCreationStep != $1.pinCreationStep },
                        callback: {
                            if case .saveSuccess = $0.pinCreationStep {
                                self.modalPresenter?.walletManager = self.walletManager
                                self.feeUpdater?.updateWalletFees()
                                self.feeUpdater?.refresh()
                                self.initKVStoreCoordinator()
                            }
        })
    }

    private func initKVStoreCoordinator() {
        guard let kvStore = apiClient?.kv else { return }
        guard kvStoreCoordinator == nil else { return }
        walletCoordinator?.kvStore = kvStore
        kvStoreCoordinator = KVStoreCoordinator(store: store, kvStore: kvStore)
        kvStoreCoordinator?.retreiveStoredWalletName()
        kvStoreCoordinator?.listenForWalletChanges()
    }
}
