//
//  WhiteDecimalPad.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-03-16.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

class WhiteDecimalPad: GenericPinPadCell {

    override var style: PinPadStyle {
        get { return .white }
        set {}
    }

    override func setAppearance() {
        if isHighlighted {
            label.backgroundColor = .secondaryShadow
            label.textColor = .darkText
        } else {
            label.backgroundColor = .white
            label.textColor = .grayTextTint
        }
    }

    override func addConstraints() {
        label.constrain(toSuperviewEdges: nil)
        imageView.constrain(toSuperviewEdges: nil)
    }
}
