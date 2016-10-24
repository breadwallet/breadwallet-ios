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

    //TODO - delete all these views, this is all just for playing
    //with store subscriptions
    let label = UILabel(frame: CGRect(x: 0, y: 100, width: 320, height: 44))
    let upButton: UIButton = {
        let button: UIButton = UIButton(type: .system)
        button.setTitle("Up", for: .normal)
        button.frame = CGRect(x: 0, y: 40, width: 100, height: 44)
        button.layer.borderColor = UIColor.brand.cgColor
        button.layer.borderWidth = 1.0
        button.layer.cornerRadius = 4.0
        return button
    }()
    let downButton: UIButton = {
        let button: UIButton = UIButton(type: .system)
        button.setTitle("Down", for: .normal)
        button.frame = CGRect(x: 100, y: 40, width: 100, height: 44)
        button.layer.borderColor = UIColor.brand.cgColor
        button.layer.borderWidth = 1.0
        button.layer.cornerRadius = 4.0
        return button
    }()

    init(store: Store, tabBarItem: UITabBarItem) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
        self.tabBarItem = tabBarItem
    }

    override func viewDidLoad() {
        view.backgroundColor = .white

        upButton.addTarget(self, action: #selector(up), for: .touchUpInside)
        downButton.addTarget(self, action: #selector(down), for: .touchUpInside)

        view.addSubview(upButton)
        view.addSubview(downButton)
        view.addSubview(label)
    }

    func up() {
        store.perform(action: IncrementImportantValue())
    }

    func down() {
        store.perform(action: DecrementImportantValue())
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        let subscription = GranularSubscription(selector: { $0.count }, callback: { count in
            self.label.text = "\(self.tabBarItem!.title!) Important number: \(count)"
        })
        store.granularSubscription(self, subscription: subscription)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        store.unsubscribe(self)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
