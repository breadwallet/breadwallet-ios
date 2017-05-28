//
//  StartNavigationDelegate.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-27.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

class StartNavigationDelegate : NSObject, UINavigationControllerDelegate {

    let store: Store

    init(store: Store) {
        self.store = store
    }

    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {

        if viewController is RecoverWalletIntroViewController {
            navigationController.navigationBar.tintColor = .white
            navigationController.navigationBar.titleTextAttributes = [
                NSForegroundColorAttributeName: UIColor.white,
                NSFontAttributeName: UIFont.customBold(size: 17.0)
            ]
            navigationController.setClearNavbar()
            navigationController.navigationBar.barTintColor = .clear
        }

        if viewController is RecoverWalletViewController {
            navigationController.navigationBar.tintColor = .darkText
            navigationController.navigationBar.titleTextAttributes = [
                NSForegroundColorAttributeName: UIColor.darkText,
                NSFontAttributeName: UIFont.customBold(size: 17.0)
            ]
            navigationController.setClearNavbar()
            navigationController.navigationBar.isTranslucent = false
            navigationController.navigationBar.barTintColor = .whiteTint
        }

        if viewController is UpdatePinViewController {
            navigationController.navigationBar.tintColor = .darkText
            navigationController.navigationBar.titleTextAttributes = [
                NSForegroundColorAttributeName: UIColor.darkText,
                NSFontAttributeName: UIFont.customBold(size: 17.0)
            ]
            navigationController.setClearNavbar()
        }

        if viewController is UpdatePinViewController {
            if let gr = navigationController.interactivePopGestureRecognizer {
                navigationController.view.removeGestureRecognizer(gr)
            }
        }
    }
}
