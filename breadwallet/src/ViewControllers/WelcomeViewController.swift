//
//  WelcomeViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-11-14.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

class WelcomeViewController: UIViewController {

    private let store: Store

    init(store: Store) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
