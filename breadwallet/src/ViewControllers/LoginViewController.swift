//
//  LoginViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-01-19.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

class LoginViewController : UIViewController {

    //MARK: - Public
    init(store: Store) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }

    //MARK: - Private
    private let store: Store
    private let backgroundView = LoginBackgroundView()
    private let textField = UITextField()

    override func viewDidLoad() {
        view.addSubview(backgroundView)
        backgroundView.constrain(toSuperviewEdges: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
