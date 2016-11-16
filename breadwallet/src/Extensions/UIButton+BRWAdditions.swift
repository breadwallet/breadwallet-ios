//
//  UIButton+BRWAdditions.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-24.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

extension UIButton {
    static func close() -> UIButton {
        let button = UIButton(type: .system)
        button.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        button.setImage(#imageLiteral(resourceName: "Close"), for: .normal)
        button.tintColor = .black
        button.accessibilityLabel = NSLocalizedString("Close", comment: "Close modal button accessibility label")
        return button
    }
}
