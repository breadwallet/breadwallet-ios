//
//  SendViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-21.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

class SendViewController: UIViewController, Subscriber {

    let store: Store
    init(store: Store, tabBarItem: UITabBarItem) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
        self.tabBarItem = tabBarItem
    }

    override func viewDidLoad() {
        view.backgroundColor = .white
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
