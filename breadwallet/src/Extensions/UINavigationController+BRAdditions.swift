//
//  UINavigationController+BRAdditions.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-11-29.
//  Copyright © 2016-2019 Breadwinner AG. All rights reserved.
//

import UIKit

extension UINavigationController {

    func setDefaultStyle() {
        setClearNavbar()
        navigationBar.tintColor = .darkText
        navigationBar.titleTextAttributes = [
            NSAttributedString.Key.font: UIFont.header
        ]
    }

    func setWhiteStyle() {
        navigationBar.tintColor = .white
        navigationBar.titleTextAttributes = [
            NSAttributedString.Key.foregroundColor: UIColor.white,
            NSAttributedString.Key.font: UIFont.header
        ]
    }
    
    func setDarkStyle() {
        navigationBar.isTranslucent = false
        navigationBar.barStyle = .blackOpaque
        navigationBar.barTintColor = .navigationBackground
        navigationBar.tintColor = .navigationTint
        navigationBar.titleTextAttributes = [
            NSAttributedString.Key.foregroundColor: UIColor.white,
            NSAttributedString.Key.font: UIFont.header
        ]
    }

    func setClearNavbar() {
        navigationBar.setBackgroundImage(UIImage(), for: .default)
        navigationBar.shadowImage = UIImage()
        navigationBar.isTranslucent = true
    }
}
