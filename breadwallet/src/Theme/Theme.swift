//
//  Theme.swift
//  breadwallet
//
//  Created by Ray Vander Veen on 2019-05-27
//  Copyright © 2019 Breadwinner AG. All rights reserved.
//

import UIKit

/**
 *  Standardizes colors and fonts.
 */
protocol BRDTheme {
    
    //
    // Fonts
    //
    
    static var h0Title: UIFont { get }
    static var h1Title: UIFont { get }
    static var h2Title: UIFont { get }
    static var h3Title: UIFont { get }

    static var body1: UIFont { get }
    static var body1Accent: UIFont { get }
    static var body2: UIFont { get }
    
    static var primaryButton: UIFont { get }
    
    //
    // Colors
    //
    
    static var primaryBackground: UIColor { get }
    static var secondaryBackground: UIColor { get }
    static var tertiaryBackground: UIColor { get }
    
    static var primaryText: UIColor { get }
    static var secondaryText: UIColor { get }
    static var tertiaryText: UIColor { get }
    
    static var accent: UIColor { get }
    static var accentHighlighted: UIColor { get }
    static var error: UIColor { get }
    static var success: UIColor { get }

}

//
// Default theme implementation.
//

class Theme: BRDTheme {
    
    static let circularProBook = "CircularPro-Book"
    static let circularProMedium = "CircularPro-Medium"
    
    // Font sizes
    enum FontSize: CGFloat {
        case h0Title = 36.0
        case h1Title = 28.0
        case h2Title = 24.0
        case h3Title = 18.0
        case body1 = 16.0
        case body2 = 14.0
        case caption = 12.0
    }
    
    enum FontName: String {
        case book = "CircularPro-Book"
        case medium = "CircularPro-Medium"
        case bold = "CircularPro-Bold"
    }
    
    enum ColorHex: String {
        case primaryBackground = "#141233"
        case secondaryBackground = "#211F3F"
        case tertiaryBackground = "#312F4C"
        
        case text = "#FFFFFF"
        
        case accent = "#5B6DEE"
        case accentHighlighted = "#5667E0"
        case success = "#5BE081"
        case error = "#EA6654"
    }

    enum TextAlpha: CGFloat {
        case primary = 1.0
        case secondary = 0.75
        case tertiary = 0.6
    }
    
    //
    // Fonts
    //
    
    static var h0Title: UIFont {
        return font(.h0Title, .headline)
    }
    
    static var h1Title: UIFont {
        return font(.h1Title, .title1)
    }
    
    static var h2Title: UIFont {
        return font(.h2Title, .title2)
    }
    
    static var h3Title: UIFont {
        return font(.h3Title, .title3)
    }
    
    static var body1: UIFont {
        return font(.body1, .body )
    }
    
    static var body1Accent: UIFont {
        return font(.bold, .body1, .body)
    }
    
    static var h3Accent: UIFont {
        return font(.bold, .h3Title, .body)
    }
    
    static var body2: UIFont {
        return font(.body2, .body)
    }
    
    static var body3: UIFont {
        return font(.medium, .body2, .body)
    }
    
    static var caption: UIFont {
        return font(.caption, .caption1)
    }
    
    static var primaryButton: UIFont {
        return font(.body1, .body)
    }
    
    //
    // Colors
    //
    
    static var primaryBackground: UIColor {
        return color(.primaryBackground)
    }
    
    static var secondaryBackground: UIColor {
        return color(.secondaryBackground)
    }
    
    static var tertiaryBackground: UIColor {
        return color(.tertiaryBackground)
    }
    
    static var primaryText: UIColor {
        return color(.text)
    }
    
    static var secondaryText: UIColor {
        return primaryText.withAlphaComponent(TextAlpha.secondary.rawValue)
    }
    
    static var tertiaryText: UIColor {
        return primaryText.withAlphaComponent(TextAlpha.tertiary.rawValue)
    }
    
    static var accent: UIColor {
        return color(.accent)
    }
    
    static var accentHighlighted: UIColor {
        return color(.accentHighlighted)
    }
    
    static var error: UIColor {
        return color(.error)
    }
    
    static var success: UIColor {
        return color(.success)
    }
    
    // returns a font with the given size with the default typeface
    private static func font(_ size: FontSize, _ fallbackStyle: UIFont.TextStyle) -> UIFont {
        return font(.book, size, fallbackStyle)
    }

    // returns a font with the given typeface and size
    private static func font(_ name: FontName, _ size: FontSize, _ fallbackStyle: UIFont.TextStyle) -> UIFont {
        guard let font = UIFont(name: name.rawValue, size: size.rawValue)
            else { return UIFont.preferredFont(forTextStyle: fallbackStyle) }
        return font
    }
    
    // returns a color with the given enum
    private static func color(_ hex: ColorHex) -> UIColor {
        return UIColor.fromHex(hex.rawValue)
    }
}
