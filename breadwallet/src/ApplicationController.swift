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
    let window =                    UIWindow()
    private let store =             Store()
    private var startFlowController: StartFlowPresenter?
    private var alertCoordinator: AlertCoordinator?

    func launch(options: [UIApplicationLaunchOptionsKey: Any]?) {
        setupAppearance()
        setupRootViewController()
        setupAlertCoordinator()
        window.makeKeyAndVisible()
        startEventManager()
        //store.perform(action: ShowStartFlow())
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
        startFlowController = StartFlowPresenter(store: store, rootViewController: accountViewController)
    }

    private func setupAlertCoordinator() {
        alertCoordinator = AlertCoordinator(store: store, window: window)
    }
}
