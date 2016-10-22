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
    let window = UIWindow()

    func launch(options: [UIApplicationLaunchOptionsKey: Any]?) {
        window.makeKeyAndVisible()
        setupRootViewController()
    }

    private func setupRootViewController() {
        let tabBarController = UITabBarController()
        tabBarController.viewControllers = [
            SendViewController(tabBarItem: UITabBarItem(title: "SEND", image: nil, selectedImage: nil)),
            ReceiveViewController(tabBarItem: UITabBarItem(title: "RECEIVE", image: nil, selectedImage: nil)),
            MenuViewController(tabBarItem: UITabBarItem(title: "MENU", image: nil, selectedImage: nil))
        ]
        window.rootViewController = tabBarController
    }
}
