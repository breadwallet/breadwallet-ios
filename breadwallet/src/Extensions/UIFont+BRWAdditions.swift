//
//  UIFont+BRWAdditions.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-27.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

extension UIFont {
    static var header: UIFont {
        guard let font = UIFont(name: "CircularPro-Bold", size: 18.0) else { return UIFont.preferredFont(forTextStyle: .headline) }
        return font
    }
    static func customBold(size: CGFloat) -> UIFont {
        guard let font = UIFont(name: "CircularPro-Bold", size: size) else { return UIFont.preferredFont(forTextStyle: .headline) }
        return font
    }
    static func customBody(size: CGFloat) -> UIFont {
        guard let font = UIFont(name: "CircularPro-Book", size: size) else { return UIFont.preferredFont(forTextStyle: .subheadline) }
        return font
    }
    static func customMedium(size: CGFloat) -> UIFont {
        guard let font = UIFont(name: "CircularPro-Medium", size: size) else { return UIFont.preferredFont(forTextStyle: .body) }
        return font
    }
    static func emailPlaceholder() -> UIFont {
        guard let font = UIFont(name: "CircularPro-Book", size: 15.0) else { return UIFont.preferredFont(forTextStyle: .body) }
        return font
    }
    static func onboardingHeading() -> UIFont {
        guard let font = UIFont(name: "CircularPro-Book", size: 24.0) else { return UIFont.preferredFont(forTextStyle: .headline) }
        return font        
    }
    static func onboardingSmallHeading() -> UIFont {
        guard let font = UIFont(name: "CircularPro-Book", size: 18.0) else { return UIFont.preferredFont(forTextStyle: .headline) }
        return font        
    }
    static func onboardingSubheading() -> UIFont {
        guard let font = UIFont(name: "CircularPro-Book", size: 14.0) else { return UIFont.preferredFont(forTextStyle: .body) }
        return font                
    }
    static func onboardingSkipButton() -> UIFont {
        guard let font = UIFont(name: "CircularPro-Book", size: 14.0) else { return UIFont.preferredFont(forTextStyle: .body) }
        return font                
    }
    
    static var h0Title: UIFont {
        guard let font = UIFont(name: "CircularPro-Book", size: 40.0) else { return UIFont.preferredFont(forTextStyle: .title1) }
        return font
    }
    
    static var h2Title: UIFont {
        guard let font = UIFont(name: "CircularPro-Book", size: 24.0) else { return UIFont.preferredFont(forTextStyle: .headline) }
        return font
    }

    static var h3Title: UIFont {
        guard let font = UIFont(name: "CircularPro-Book", size: 18.0) else { return UIFont.preferredFont(forTextStyle: .headline) }
        return font
    }

    static var body1: UIFont {
        guard let font = UIFont(name: "CircularPro-Book", size: 16.0) else { return UIFont.preferredFont(forTextStyle: .body) }
        return font
    }
    
    static var body2: UIFont {
        guard let font = UIFont(name: "CircularPro-Book", size: 14.0) else { return UIFont.preferredFont(forTextStyle: .body) }
        return font
    }
    
    static var caption: UIFont {
        guard let font = UIFont(name: "CircularPro-Book", size: 12.0) else { return UIFont.preferredFont(forTextStyle: .body) }
        return font
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
