//
//  UIButton+BRWAdditions.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-24.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

extension UIButton {
    static func vertical(title: String, image: UIImage) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setImage(image, for: .normal)

        if let imageSize = button.imageView?.image?.size,
            let font = button.titleLabel?.font {
            let spacing: CGFloat = C.padding[1]/2.0
            let titleSize = NSString(string: title).size(attributes: [NSFontAttributeName : font])

            //These edge insets place the image vertically above the title label
            button.titleEdgeInsets = UIEdgeInsetsMake(0.0, -imageSize.width, -(imageSize.height + spacing), 0.0)
            button.imageEdgeInsets = UIEdgeInsetsMake(-(titleSize.height + spacing), 0.0, 0.0, -titleSize.width)
        }

        return button
    }

    static func close() -> UIButton {
        let button = UIButton(type: .system)
        button.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        button.setImage(#imageLiteral(resourceName: "Close"), for: .normal)
        button.tintColor = .darkText
        button.accessibilityLabel = NSLocalizedString("Close", comment: "Close modal button accessibility label")
        return button
    }

    static func faq() -> UIButton {
        let button = UIButton(type: .system)
        button.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        button.setImage(#imageLiteral(resourceName: "Faq"), for: .normal)
        button.tintColor = .darkText
        button.accessibilityLabel = NSLocalizedString("Faq", comment: "Frequently asked questions button accessibility label")
        return button
    }
}
