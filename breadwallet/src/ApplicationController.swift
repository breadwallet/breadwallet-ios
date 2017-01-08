//
//  ApplicationController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-21.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

class ApplicationController: EventManagerCoordinator {

    //Ideally the window would be private, but is unfortunately required
    //by the UIApplicationDelegate Protocol
    let window = UIWindow()
    private let store = Store()
    private var startFlowController: StartFlowPresenter?
    private var modalPresenter: ModalPresenter?

    private let walletManager = try! WalletManager(dbPath: nil)
    private var walletCreator: WalletCreator?
    private var walletCoordinator: WalletCoordinator?

    func launch(options: [UIApplicationLaunchOptionsKey: Any]?) {
        setupAppearance()
        setupRootViewController()
        setupPresenters()
        window.makeKeyAndVisible()
        startEventManager()

        if walletManager.noWallet {
            walletCreator = WalletCreator(walletManager: walletManager, store: store)
            store.perform(action: ShowStartFlow())
        } else {
            DispatchQueue(label: "com.breadwallet.BRCore").async {
                self.walletManager.peerManager?.connect()
            }
        }
        walletCoordinator = WalletCoordinator(walletManager: walletManager, store: store)
    }

    func performFetch(_ completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        syncEventManager()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: {
            completionHandler(.newData)
        })
    }

    private func setupAppearance() {
        window.tintColor = .brand
        UINavigationBar.appearance().titleTextAttributes = [NSFontAttributeName: UIFont.header]
        //Hack to globally hide the back button text
        UIBarButtonItem.appearance().setBackButtonTitlePositionAdjustment(UIOffsetMake(-500.0, -500.0), for: .default)
    }

    private func setupRootViewController() {
        let accountViewController = AccountViewController(store: store)
        window.rootViewController = accountViewController
        accountViewController.sendCallback = { self.store.perform(action: RootModalActions.Send()) }
        accountViewController.receiveCallback = { self.store.perform(action: RootModalActions.Receive()) }
        accountViewController.menuCallback = { self.store.perform(action: RootModalActions.Menu()) }
        startFlowController = StartFlowPresenter(store: store, walletManager: walletManager, rootViewController: accountViewController)
    }

    private func setupPresenters() {
        modalPresenter = ModalPresenter(store: store, window: window)
    }
}
