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

    func addCloseNavigationItem(tintColor: UIColor? = nil) {
        let close = UIButton.close
        close.tap = { [weak self] in
            self?.dismiss(animated: true, completion: nil)
        }
        if let color = tintColor {
            close.tintColor = color
        }
        navigationItem.leftBarButtonItems = [UIBarButtonItem.negativePadding, UIBarButtonItem(customView: close)]
    }
    
    func addCustomBackButton() {
        let backButton = UIButton(type:.system)
        backButton.setImage(#imageLiteral(resourceName: "LeftArrow"), for: .normal)
        backButton.frame = CGRect(x: 0, y: 0, width: 48, height: 48)
        backButton.imageEdgeInsets = UIEdgeInsets(top: 12.0, left: 0.0, bottom: 12.0, right: 24.0)
        backButton.tap = {
            self.navigationController?.popViewController(animated: true)
        }
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: backButton)
        navigationItem.hidesBackButton = true
    }
}
