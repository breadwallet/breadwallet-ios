//
//  UIButton+BRWAdditions.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-24.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

extension UIButton {
    static func primary(title: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.backgroundColor = .brand
        button.layer.cornerRadius = 5.0
        button.tintColor = .white
        button.titleLabel?.font = UIFont.customMedium(size: 16.0)
        button.accessibilityLabel = title
        return button
    }

    static func secondary(title: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.backgroundColor = .offWhite
        button.layer.borderColor = UIColor.borderGray.cgColor
        button.layer.borderWidth = 1.0
        button.layer.cornerRadius = 5.0
        button.tintColor = .black
        button.titleLabel?.font = UIFont.customMedium(size: 16.0)
        button.accessibilityLabel = title
        return button
    }

    static func close() -> UIButton {
        let button = UIButton(type: .system)
        button.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        button.setImage(#imageLiteral(resourceName: "Close"), for: .normal)
        button.tintColor = .black
        button.accessibilityLabel = NSLocalizedString("Close", comment: "Close modal button accessibility label")
        return button
    }
}
