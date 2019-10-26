//
//  UIColor+BRWAdditions.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-21.
//  Copyright © 2016-2019 Breadwinner AG. All rights reserved.
//

import UIKit

extension UIColor {
        
    static var newGradientStart: UIColor {
        return UIColor.fromHex("FB5491")
    }

    static var newGradientEnd: UIColor {
        return UIColor.fromHex("FAA03F")
    }

    static var darkBackground: UIColor {
        return Theme.primaryBackground
    }
    
    static var darkPromptBackground: UIColor {
        return UIColor.fromHex("3E334F")
    }

    static var darkPromptTitleColor: UIColor {
        return .white
    }

    static var darkPromptBodyColor: UIColor {
        return UIColor.fromHex("A1A9BC")
    }
    
    static var emailInputBackgroundColor: UIColor {
        return UIColor.fromHex("F8F7FC").withAlphaComponent(0.05)
    }
    
    static var submitButtonEnabledBlue: UIColor {
        return UIColor.fromHex("29ABE2")
    }
    
    static var orangeText: UIColor {
        return UIColor.fromHex("FA724D")
    }
    
    static var newWhite: UIColor {
        return UIColor.fromHex("BDBDBD")
    }
    
    static var greenCheck: UIColor {
        return UIColor.fromHex("06C441")
    }
    
    static var disabledBackground: UIColor {
        return UIColor.fromHex("3E3C61")
    }

    // MARK: Buttons
    static var primaryButton: UIColor {
        return UIColor.fromHex("5B6DEE")
    }
    
    static var orangeButton: UIColor {
        return UIColor.fromHex("E7AA41")
    }

    static var secondaryButton: UIColor {
        return UIColor(red: 245.0/255.0, green: 247.0/255.0, blue: 250.0/255.0, alpha: 1.0)
    }

    static var secondaryBorder: UIColor {
        return UIColor(red: 213.0/255.0, green: 218.0/255.0, blue: 224.0/255.0, alpha: 1.0)
    }

    // MARK: text color
        
    static var darkText: UIColor {
        return UIColor.fromHex("4F4F4F")
    }

    static var lightText: UIColor {
        return UIColor.fromHex("828282")
    }

    static var lightHeaderBackground: UIColor {
        return UIColor.fromHex("F9F9F9")
    }

    static var lightTableViewSectionHeaderBackground: UIColor {
        return UIColor.fromHex("ECECEC")
    }

    static var darkLine: UIColor {
        return UIColor(red: 36.0/255.0, green: 35.0/255.0, blue: 38.0/255.0, alpha: 1.0)
    }

    static var secondaryShadow: UIColor {
        return UIColor(red: 213.0/255.0, green: 218.0/255.0, blue: 224.0/255.0, alpha: 1.0)
    }

    // MARK: Gradient
    static var gradientStart: UIColor {
        return UIColor(red: 247.0/255.0, green: 164.0/255.0, blue: 69.0/255.0, alpha: 1.0)
    }

    static var gradientEnd: UIColor {
        return UIColor(red: 252.0/255.0, green: 83.0/255.0, blue: 148.0/255.0, alpha: 1.0)
    }

    static var offWhite: UIColor {
        return UIColor(white: 247.0/255.0, alpha: 1.0)
    }

    static var borderGray: UIColor {
        return UIColor(white: 221.0/255.0, alpha: 1.0)
    }

    static var separatorGray: UIColor {
        return UIColor(white: 221.0/255.0, alpha: 1.0)
    }

    static var grayText: UIColor {
        return UIColor(white: 136.0/255.0, alpha: 1.0)
    }

    static var grayTextTint: UIColor {
        return UIColor(red: 163.0/255.0, green: 168.0/255.0, blue: 173.0/255.0, alpha: 1.0)
    }

    static var secondaryGrayText: UIColor {
        return UIColor(red: 101.0/255.0, green: 105.0/255.0, blue: 110.0/255.0, alpha: 1.0)
    }
    
    static var emailPlaceholderText: UIColor {
        return UIColor.fromHex("828092")
    }
    
    static var grayBackgroundTint: UIColor {
        return UIColor(red: 250.0/255.0, green: 251.0/255.0, blue: 252.0/255.0, alpha: 1.0)
    }

    static var cameraGuidePositive: UIColor {
        return UIColor(red: 72.0/255.0, green: 240.0/255.0, blue: 184.0/255.0, alpha: 1.0)
    }

    static var cameraGuideNegative: UIColor {
        return UIColor(red: 240.0/255.0, green: 74.0/255.0, blue: 93.0/255.0, alpha: 1.0)
    }

    static var purple: UIColor {
        return UIColor(red: 209.0/255.0, green: 125.0/255.0, blue: 245.0/255.0, alpha: 1.0)
    }

    static var darkPurple: UIColor {
        return UIColor(red: 127.0/255.0, green: 83.0/255.0, blue: 230.0/255.0, alpha: 1.0)
    }

    static var pink: UIColor {
        return UIColor(red: 252.0/255.0, green: 83.0/255.0, blue: 148.0/255.0, alpha: 1.0)
    }

    static var blue: UIColor {
        return UIColor(red: 76.0/255.0, green: 152.0/255.0, blue: 252.0/255.0, alpha: 1.0)
    }

    static var whiteTint: UIColor {
        return UIColor(red: 245.0/255.0, green: 247.0/255.0, blue: 250.0/255.0, alpha: 1.0)
    }
    
    static var outlineButtonBackground: UIColor {
        return UIColor(red: 174.0/255.0, green: 174.0/255.0, blue: 174.0/255.0, alpha: 0.3)
    }

    static var transparentWhite: UIColor {
        return UIColor(white: 1.0, alpha: 0.3)
    }
    
    static var transparentWhiteText: UIColor {
        return UIColor(white: 1.0, alpha: 0.75)
    }
    
    static var disabledWhiteText: UIColor {
        return UIColor(white: 1.0, alpha: 0.5)
    }

    static var transparentBlack: UIColor {
        return UIColor(white: 0.0, alpha: 0.3)
    }
    
    static var transparentButton: UIColor {
        return UIColor(white: 1.0, alpha: 0.2)
    }

    static var darkOpaqueButton: UIColor {
        return UIColor(white: 1.0, alpha: 0.05)
    }
    
    static var blueGradientStart: UIColor {
        return UIColor(red: 99.0/255.0, green: 188.0/255.0, blue: 255.0/255.0, alpha: 1.0)
    }

    static var blueGradientEnd: UIColor {
        return UIColor(red: 56.0/255.0, green: 141.0/255.0, blue: 252.0/255.0, alpha: 1.0)
    }

    static var txListGreen: UIColor {
        return UIColor(red: 0.0, green: 169.0/255.0, blue: 157.0/255.0, alpha: 1.0)
    }
    
    static var blueButtonText: UIColor {
        return UIColor(red: 127.0/255.0, green: 181.0/255.0, blue: 255.0/255.0, alpha: 1.0)
    }
    
    static var darkGray: UIColor {
        return UIColor(red: 84.0/255.0, green: 104.0/255.0, blue: 117.0/255.0, alpha: 1.0)
    }
    
    static var lightGray: UIColor {
        return UIColor(red: 179.0/255.0, green: 192.0/255.0, blue: 200.0/255.0, alpha: 1.0)
    }
    
    static var mediumGray: UIColor {
        return UIColor(red: 120.0/255.0, green: 143.0/255.0, blue: 158.0/255.0, alpha: 1.0)
    }
    
    static var receivedGreen: UIColor {
        return UIColor(red: 155.0/255.0, green: 213.0/255.0, blue: 85.0/255.0, alpha: 1.0)
    }
    
    static var failedRed: UIColor {
        return UIColor(red: 244.0/255.0, green: 107.0/255.0, blue: 65.0/255.0, alpha: 1.0)
    }
    
    static var statusIndicatorActive: UIColor {
        return UIColor(red: 75.0/255.0, green: 119.0/255.0, blue: 243.0/255.0, alpha: 1.0)
    }
    
    static var grayBackground: UIColor {
        return UIColor(red: 224.0/255.0, green: 229.0/255.0, blue: 232.0/255.0, alpha: 1.0)
    }
    
    static var whiteBackground: UIColor {
        return UIColor(red: 249.0/255.0, green: 251.0/255.0, blue: 254.0/255.0, alpha: 1.0)
    }
    
    static var separator: UIColor {
        return UIColor(red: 236.0/255.0, green: 236.0/255.0, blue: 236.0/255.0, alpha: 1.0)
    }
    
    static var navigationTint: UIColor {
        return .white
    }
    
    static var navigationBackground: UIColor {
        return Theme.primaryBackground
    }
    
    static var transparentCellBackground: UIColor {
        return UIColor(white: 1.0, alpha: 0.03)
    }
    
    static var transparentIconBackground: UIColor {
        return UIColor(white: 1.0, alpha: 0.25)
    }
    
    static var disabledCellBackground: UIColor {
        return UIColor.fromHex("190C2A")
    }
    
    static var pageIndicatorDotBackground: UIColor {
        return UIColor.fromHex("1F1E3D")
    }
    
    static var pageIndicatorDot: UIColor {
        return  UIColor.fromHex("027AFF")
    }
    
    static var onboardingHeadingText: UIColor {
        return .white
    }
    
    static var onboardingSubheadingText: UIColor {
        return UIColor.fromHex("8B89A1")
    }
    
    static var onboardingSkipButtonTitle: UIColor {
        return UIColor.fromHex("8B89A1")
    }
    
    static var onboardingOrangeText: UIColor {
        return UIColor.fromHex("EA8017")
    }

    static var rewardsViewNormalTitle: UIColor {
        return UIColor.fromHex("2A2A2A")
    }

    static var rewardsViewExpandedTitle: UIColor {
        return UIColor.fromHex("441E36")
    }

    static var rewardsViewExpandedBody: UIColor {
        return UIColor.fromHex("#441E36").withAlphaComponent(0.7)
    }
}

extension UIColor {
    static func fromHex(_ hex: String) -> UIColor {
        var sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if sanitized.hasPrefix("#") {
            sanitized.remove(at: sanitized.startIndex)
        }
        guard sanitized.count == 6 else { return .lightGray }
        var rgbValue: UInt32 = 0
        Scanner(string: sanitized).scanHexInt32(&rgbValue)
        return UIColor(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: CGFloat(1.0))
    }
    
    var toHex: String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        let rgb: Int = (Int)(r*255)<<16 | (Int)(g*255)<<8 | (Int)(b*255)<<0
        return String(format: "#%06x", rgb)
    }
}
