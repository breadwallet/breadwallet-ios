//
//  ClearPinPadCell.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-01-23.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

class ClearPinPadCell : PinPadCell {

    override func setColors() {
        if isHighlighted {
            label.backgroundColor = .secondaryShadow
            label.textColor = .darkText
        } else {
            label.backgroundColor = UIColor(white: 1.0, alpha: 0.3)
            label.textColor = .white
        }
    }
}
