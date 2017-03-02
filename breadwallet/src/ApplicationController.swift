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

    private let walletManager: WalletManager = try! WalletManager(dbPath: nil)
    private let walletCreator: WalletCreator
    private let walletCoordinator: WalletCoordinator
    lazy private var apiClient: BRAPIClient = BRAPIClient(authenticator: self.walletManager)
    private var exchangeManager: ExchangeUpdater?
    private var feeUpdater: FeeUpdater?
    private let transitionDelegate: ModalTransitionDelegate

    init() {
        walletCreator = WalletCreator(walletManager: walletManager, store: store)
        walletCoordinator = WalletCoordinator(walletManager: walletManager, store: store)
        transitionDelegate = ModalTransitionDelegate(store: store, type: .transactionDetail)
    }

    func launch(options: [UIApplicationLaunchOptionsKey: Any]?) {
        setupDefaults()
        setupAppearance()
        setupRootViewController()
        setupPresenters()
        window.makeKeyAndVisible()
        startEventManager()

        if walletManager.noWallet {
            addWalletCreationListener()
            store.perform(action: ShowStartFlow())
        } else {
            if shouldRequireLogin() {
                store.perform(action: RequireLogin())
            }
            modalPresenter?.walletManager = walletManager
            DispatchQueue.global(qos: .background).async {
                self.walletManager.peerManager?.connect()
            }
        }
        exchangeManager = ExchangeUpdater(store: store, apiClient: apiClient)
        exchangeManager?.refresh()
        feeUpdater = FeeUpdater(walletManager: walletManager, apiClient: apiClient)
        feeUpdater?.refresh()
    }

    func willEnterForeground() {
        guard !walletManager.noWallet else { return }
        if shouldRequireLogin() {
            store.perform(action: RequireLogin())
        }
        DispatchQueue.global(qos: .background).async {
            self.walletManager.peerManager?.connect() //TODO - guard for noWallet?
        }
        exchangeManager?.refresh()
        feeUpdater?.refresh()
    }

    func didEnterBackground() {
        //Save the backgrounding time if the user is logged in
        if !store.state.isLoginRequired {
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: timeSinceLastExitKey)
        }
    }

    func performFetch(_ completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        syncEventManager()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: {
            completionHandler(.newData)
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
        window.tintColor = .brand
        UINavigationBar.appearance().titleTextAttributes = [NSFontAttributeName: UIFont.header]
        //Hack to globally hide the back button text
        UIBarButtonItem.appearance().setBackButtonTitlePositionAdjustment(UIOffsetMake(-500.0, -500.0), for: .default)
    }

    private func setupRootViewController() {

        let didSelectTransaction: ([Transaction], Int) -> Void = { transactions, selectedIndex in
            let transactionDetails = TransactionDetailsViewController(store: self.store, transactions: transactions, selectedIndex: selectedIndex)
            transactionDetails.modalPresentationStyle = .overFullScreen
            transactionDetails.transitioningDelegate = self.transitionDelegate
            transactionDetails.modalPresentationCapturesStatusBarAppearance = true
            self.window.rootViewController?.present(transactionDetails, animated: true, completion: nil)
        }

        let accountViewController = AccountViewController(store: store, didSelectTransaction: didSelectTransaction)
        window.rootViewController = accountViewController
        accountViewController.sendCallback = { self.store.perform(action: RootModalActions.Send()) }
        accountViewController.receiveCallback = { self.store.perform(action: RootModalActions.Receive()) }
        accountViewController.menuCallback = { self.store.perform(action: RootModalActions.Menu()) }
        startFlowController = StartFlowPresenter(store: store, walletManager: walletManager, rootViewController: accountViewController)
    }

    private func setupPresenters() {
        modalPresenter = ModalPresenter(store: store, window: window)
    }

    private func addWalletCreationListener() {
        store.subscribe(self,
                        selector: { $0.alert != $1.alert},
                        callback: {
                            guard let alert = $0.alert else { return }
                            if case .pinSet = alert {
                                self.modalPresenter?.walletManager = self.walletManager
                                self.feeUpdater?.refresh()
                            }
        })
    }
}
