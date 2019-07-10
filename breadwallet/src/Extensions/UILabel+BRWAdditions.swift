//
//  UILabel+BRWAdditions.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-26.
//  Copyright © 2016-2019 Breadwinner AG. All rights reserved.
//

import UIKit

extension UILabel {
    static func wrapping(font: UIFont, color: UIColor) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.font = font
        label.textColor = color
        return label
    }

    static func wrapping(font: UIFont) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.font = font
        return label
    }

    convenience init(font: UIFont) {
        self.init()
        self.font = font
    }

    convenience init(font: UIFont, color: UIColor) {
        self.init()
        self.font = font
        self.textColor = color
    }

    func pushNewText(_ newText: String) {
        let animation: CATransition = CATransition()
        animation.timingFunction = CAMediaTimingFunction(name:
            CAMediaTimingFunctionName.easeInEaseOut)
        animation.type = CATransitionType.push
        animation.subtype = CATransitionSubtype.fromTop
        animation.duration = C.animationDuration
        layer.add(animation, forKey: CATransitionType.push.rawValue)
        text = newText
    }
}
