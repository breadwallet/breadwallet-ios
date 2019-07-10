//
//  WhiteNumberPad.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-03-16.
//  Copyright © 2017-2019 Breadwinner AG. All rights reserved.
//

import UIKit

// swiftlint:disable unused_setter_value

class WhiteNumberPad: GenericPinPadCell {

    override var style: PinPadStyle {
        get { return .white }
        set {}
    }

    override func setAppearance() {
        if isHighlighted {
            backgroundColor = .secondaryShadow
            label.textColor = .darkText
        } else {
            if (text?.isEmpty ?? false) || text == PinPadViewController.SpecialKeys.delete.rawValue {
                backgroundColor = .whiteTint
                imageView.image = imageView.image?.withRenderingMode(.alwaysTemplate)
                imageView.tintColor = .grayTextTint
            } else {
                backgroundColor = .whiteTint
                label.textColor = .grayTextTint
            }
        }
    }

    override func addConstraints() {
        label.constrain(toSuperviewEdges: nil)
        imageView.constrain(toSuperviewEdges: nil)
    }
}
