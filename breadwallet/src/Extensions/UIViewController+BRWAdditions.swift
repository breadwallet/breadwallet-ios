//
//  UIViewController+BRWAdditions.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-21.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

extension UIViewController {
    func addChildViewController(_ viewController: UIViewController, layout: () -> Void) {
        addChildViewController(viewController)
        view.addSubview(viewController.view)
        layout()
        viewController.didMove(toParentViewController: self)
    }

    func remove() {
        willMove(toParentViewController: nil)
        view.removeFromSuperview()
        removeFromParentViewController()
    }
}
