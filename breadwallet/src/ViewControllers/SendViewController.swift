//
//  SendViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-21.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

class SendViewController: UIViewController, Subscriber {

    private let button = ShadowButton(title: "Present Start Flow", type: .primary)
    let store: Store
    
    init(store: Store, tabBarItem: UITabBarItem) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
        self.tabBarItem = tabBarItem
    }

    override func viewDidLoad() {
        view.backgroundColor = .white
        view.addSubview(button)
        button.constrain([
                button.constraint(.height, constant: Constants.Sizes.buttonHeight),
                button.constraint(.leading, toView: view, constant: Constants.Padding.double),
                button.constraint(.trailing, toView: view, constant: -Constants.Padding.double),
                button.constraint(.centerY, toView: view, constant: nil)
            ])
        button.addTarget(self, action: #selector(presentStart), for: .touchUpInside)
    }

    @objc private func presentStart() {
        store.perform(action: ShowStartFlow())
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
