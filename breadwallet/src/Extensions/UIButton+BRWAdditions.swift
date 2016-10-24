//
//  UIButton+BRWAdditions.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-24.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

extension UIButton {
    static func makeSolidButton(title: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.backgroundColor = .brand
        button.layer.cornerRadius = 5.0
        button.tintColor = .white
        return button
    }

    static func makeOutlineButton(title: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.backgroundColor = .offWhite
        button.layer.borderColor = UIColor.borderGray.cgColor
        button.layer.borderWidth = 1.0
        button.layer.cornerRadius = 5.0
        button.tintColor = .black
        return button
    }
}
