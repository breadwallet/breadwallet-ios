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
    var previous: UIViewController?

    init(store: Store) {
        self.store = store
    }

    func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
        guard previous != nil else { previous = viewController; return }

        if previous is PinCreationViewController && viewController is StartViewController {
            store.perform(action: PinCreation.Reset())
        }

        if previous is ConfirmPaperPhraseViewController && viewController is WritePaperPhraseViewController {
            store.perform(action: PaperPhrase.Write())
        }

        previous = viewController
    }

    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {

        if viewController is RecoverWalletIntroViewController {
            navigationController.navigationBar.tintColor = .white
            navigationController.navigationBar.titleTextAttributes = [
                NSForegroundColorAttributeName: UIColor.white,
                NSFontAttributeName: UIFont.customBold(size: 17.0)
            ]
        }

        if viewController is RecoverWalletViewController {
            navigationController.navigationBar.tintColor = .darkText
            navigationController.navigationBar.titleTextAttributes = [
                NSForegroundColorAttributeName: UIColor.darkText,
                NSFontAttributeName: UIFont.customBold(size: 17.0)
            ]
        }
    }
}
