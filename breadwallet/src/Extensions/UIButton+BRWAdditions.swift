//
//  UIButton+BRWAdditions.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-24.
//  Copyright © 2016-2019 Breadwinner AG. All rights reserved.
//

import UIKit

extension UIButton {
    static func vertical(title: String, image: UIImage) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setImage(image, for: .normal)
        button.titleLabel?.font = Theme.caption
        button.contentMode = .center
        button.imageView?.contentMode = .center
        if let imageSize = button.imageView?.image?.size,
            let font = button.titleLabel?.font {
            let spacing: CGFloat = C.padding[1]/2.0
            let titleSize = NSString(string: title).size(withAttributes: [NSAttributedString.Key.font: font])

            // These edge insets place the image vertically above the title label
            button.titleEdgeInsets = UIEdgeInsets(top: 0.0, left: -imageSize.width, bottom: -(26.0 + spacing), right: 0.0)
            button.imageEdgeInsets = UIEdgeInsets(top: -(titleSize.height + spacing), left: 0.0, bottom: 0.0, right: -titleSize.width)
        }
        return button
    }
    
    static func rounded(title: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.customMedium(size: 16.0)
        button.backgroundColor = .red
        button.layer.cornerRadius = 5
        button.layer.masksToBounds = true
        return button
    }

    static func outline(title: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.customBody(size: 14.0)
        button.tintColor = .white
        button.backgroundColor = .outlineButtonBackground
        button.layer.cornerRadius = 6
        button.layer.borderWidth = 0.5
        button.layer.borderColor = UIColor.white.cgColor
        //button.clipsToBounds = true
        return button
    }

    static var close: UIButton {
        let accessibilityLabel = E.isScreenshots ? "Close" : S.AccessibilityLabels.close
        return UIButton.icon(image: #imageLiteral(resourceName: "CloseModern"), accessibilityLabel: accessibilityLabel)
    }

    static var closeSmall: UIButton {
        let accessibilityLabel = E.isScreenshots ? "Close" : S.AccessibilityLabels.close
        return UIButton.icon(image: #imageLiteral(resourceName: "Close-X-small"), accessibilityLabel: accessibilityLabel)
    }

    static func buildFaqButton(articleId: String, currency: Currency? = nil, tapped: (() -> Void)? = nil) -> UIButton {
        let button = UIButton.icon(image: #imageLiteral(resourceName: "Faq"), accessibilityLabel: S.AccessibilityLabels.faq)
        button.tintColor = .white
        button.tap = {
            Store.trigger(name: .presentFaq(articleId, currency))
            tapped?()
        }
        return button
    }

    static func icon(image: UIImage, accessibilityLabel: String) -> UIButton {
        let button = UIButton(type: .system)
        button.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        button.setImage(image, for: .normal)

        if image == #imageLiteral(resourceName: "Close") {
            button.imageEdgeInsets = UIEdgeInsets(top: 14.0, left: 14.0, bottom: 14.0, right: 14.0)
        } else {
            button.imageEdgeInsets = UIEdgeInsets(top: 12.0, left: 12.0, bottom: 12.0, right: 12.0)
        }

        button.tintColor = .darkText
        button.accessibilityLabel = accessibilityLabel
        return button
    }
    
    static func icon(image: UIImage, title: String) -> UIButton {
        let button = UIButton(type: .custom)
        button.setTitle(title, for: .normal)
        button.setImage(image, for: .normal)
        button.titleEdgeInsets = UIEdgeInsets(top: 0, left: C.padding[2], bottom: 0, right: 0)
        button.titleLabel?.font = UIFont.customBody(size: 14.0)
        return button
    }

    func tempDisable() {
        isEnabled = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: { [weak self] in
            self?.isEnabled = true
        })
    }    
}

extension UIBarButtonItem {
    
    static func skipBarButtonItem() -> UIBarButtonItem {
        let skip = UIBarButtonItem(title: S.Button.skip, style: .plain, target: nil, action: nil)
        skip.tintColor = Theme.tertiaryText
        skip.setTitleTextAttributes([NSAttributedString.Key.font: Theme.body2], for: .normal)
        skip.setTitleTextAttributes([NSAttributedString.Key.font: Theme.body2], for: .highlighted)
        return skip
    }
}
