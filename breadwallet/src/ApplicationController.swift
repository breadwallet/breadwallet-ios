//
//  ApplicationController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-21.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

class ApplicationController {

    //Ideally the window would be private, but is unfortunately required
    //by the UIApplicationDelegate Protocol
    let window =                    UIWindow()
    private let store =             Store()
    private let sendTabBarItem =    UITabBarItem(title: "SEND", image: #imageLiteral(resourceName: "SendTabIcon"), selectedImage: nil)
    private let receiveTabBarItem = UITabBarItem(title: "RECEIVE", image: #imageLiteral(resourceName: "ReceiveTabIcon"), selectedImage: nil)
    private let menuTabBarItem =    UITabBarItem(title: "MENU", image: #imageLiteral(resourceName: "MenuTabIcon"), selectedImage: nil)

    private var startFlowController: StartFlowController?
    private var alertCoordinator: AlertCoordinator?

    func launch(options: [UIApplicationLaunchOptionsKey: Any]?) {
        setupAppearance()
        setupRootViewController()
        setupAlertCoordinator()
        window.makeKeyAndVisible()
        store.perform(action: ShowStartFlow())
    }

    private func setupAppearance() {
        window.tintColor = .brand
    }

    private func setupRootViewController() {
        let tabBarController = UITabBarController()
        tabBarController.viewControllers = [
            SendViewController(store: store, tabBarItem: sendTabBarItem),
            ReceiveViewController(tabBarItem: receiveTabBarItem),
            MenuViewController(tabBarItem: menuTabBarItem)
        ]
        window.rootViewController = tabBarController
        startFlowController = StartFlowController(store: store, rootViewController: tabBarController)
    }

    private func setupAlertCoordinator() {
        alertCoordinator = AlertCoordinator(store: store, window: window)
    }
}
