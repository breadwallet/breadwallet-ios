//
//  UIFont+BRWAdditions.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-27.
//  Copyright © 2016-2019 Breadwinner AG. All rights reserved.
//

import UIKit

extension UIFont {
    static var header: UIFont {
        return customBold(size: 18.0)
    }
    static func customBold(size: CGFloat) -> UIFont {
        guard let font = UIFont(name: "CircularPro-Bold", size: size) else { return UIFont.systemFont(ofSize: size, weight: .bold) }
        return font
    }
    static func customBody(size: CGFloat) -> UIFont {
        guard let font = UIFont(name: "CircularPro-Book", size: size) else { return UIFont.systemFont(ofSize: size, weight: .regular) }
        return font
    }
    static func customMedium(size: CGFloat) -> UIFont {
        guard let font = UIFont(name: "CircularPro-Medium", size: size) else { return UIFont.systemFont(ofSize: size, weight: .medium) }
        return font
    }
    static func emailPlaceholder() -> UIFont {
        return customBody(size: 15.0)
    }
    static func onboardingHeading() -> UIFont {
        return customBody(size: 24.0)
    }
    static func onboardingSmallHeading() -> UIFont {
        return customBody(size: 18.0)
    }
    static func onboardingSubheading() -> UIFont {
        return customBody(size: 14.0)
    }
    static func onboardingSkipButton() -> UIFont {
        return customBody(size: 14.0)
    }
            
    static var regularAttributes: [NSAttributedString.Key: Any] {
        return [
            NSAttributedString.Key.font: UIFont.customBody(size: 14.0),
            NSAttributedString.Key.foregroundColor: UIColor.darkText
        ]
    }

    static var boldAttributes: [NSAttributedString.Key: Any] {
        return [
            NSAttributedString.Key.font: UIFont.customBold(size: 14.0),
            NSAttributedString.Key.foregroundColor: UIColor.darkText
        ]
    }
}
