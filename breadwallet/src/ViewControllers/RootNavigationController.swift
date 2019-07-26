//
//  RootNavigationController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-12-05.
//  Copyright © 2017-2019 Breadwinner AG. All rights reserved.
//

import UIKit

class RootNavigationController: UINavigationController {

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    override func viewDidLoad() {
        setDarkStyle()
        
        view.backgroundColor = Theme.primaryBackground

        self.delegate = self
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension RootNavigationController: UINavigationControllerDelegate {
    func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
        if viewController is HomeScreenViewController {
            UserDefaults.selectedCurrencyCode = nil
            navigationBar.tintColor = .navigationTint
        } else if let accountView = viewController as? AccountViewController {
            UserDefaults.selectedCurrencyCode = accountView.currency.code
            //TODO:CRYPTO p2p sync management
//            if accountView.currency is Bitcoin {
//                UserDefaults.mostRecentSelectedCurrencyCode = accountView.currency.code
//            }
        }
    }
    
    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        if viewController is AccountViewController {
            navigationBar.tintColor = .white
        }
    }
    
}
