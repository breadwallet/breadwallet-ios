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
        return UIFont(name: "CircularPro-Bold", size: 17.0) ?? UIFont.preferredFont(forTextStyle: .headline)
    }
    
    static func customBold(size: CGFloat) -> UIFont {
        return UIFont(name: "CircularPro-Bold", size: size) ?? UIFont.preferredFont(forTextStyle: .headline)
    }
    
    static func customBody(size: CGFloat) -> UIFont {
        return UIFont(name: "CircularPro-Book", size: size)  ?? UIFont.preferredFont(forTextStyle: .subheadline)
    }
    
    static func customMedium(size: CGFloat) -> UIFont {
        return UIFont(name: "CircularPro-Medium", size: size) ?? UIFont.preferredFont(forTextStyle: .body)
    }
    
    static func barloweBold(size: CGFloat) -> UIFont {
        return UIFont(name: "BarlowSemiCondensed-Bold", size: size) ?? UIFont.preferredFont(forTextStyle: .body)
    }
    
    static func barloweSemiBold(size: CGFloat) -> UIFont {
        return UIFont(name: "BarlowSemiCondensed-SemiBold", size: size) ?? UIFont.preferredFont(forTextStyle: .body)
    }
    
    static func barloweItalic(size: CGFloat) -> UIFont {
        return UIFont(name: "BarlowSemiCondensed-Italic", size: size) ?? UIFont.preferredFont(forTextStyle: .body)
    }
    
    
    static func barloweMedium(size: CGFloat) -> UIFont {
        return UIFont(name: "BarlowSemiCondensed-Medium", size: size) ?? UIFont.preferredFont(forTextStyle: .body)
    }
    
    static func barloweRegular(size: CGFloat) -> UIFont {
        return UIFont(name: "BarlowSemiCondensed-Regular", size: size) ?? UIFont.preferredFont(forTextStyle: .body)
    }
    
    static func barloweLight(size: CGFloat) -> UIFont {
        return UIFont(name: "BarlowSemiCondensed-Light", size: size) ?? UIFont.preferredFont(forTextStyle: .body)
    }
    
    static var regularAttributes: [NSAttributedString.Key: Any] {
        return [
            .font: UIFont.customBody(size: 14.0),
            .foregroundColor: UIColor.darkText
        ]
    }
    
    static var boldAttributes: [NSAttributedString.Key: Any] {
        return [
            .font: UIFont.customBold(size: 14.0),
            .foregroundColor: UIColor.darkText
        ]
    }
}
