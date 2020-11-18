//
//  UIColor+BRWAdditions.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-21.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

extension UIColor {
  
  // TODO: New Color Scheme
  // #A6A9AA, Silver C, UIColor(red: 166.0/255.0, green: 169.0/255.0, blue: 170.0/255.0, alpha: 1.0)
  // #4D4D4E, Cool Gray 11 C
  // #FFFFFF, White
  // #345D9D, Blue, 7684 C, UIColor(red: 52.0/255.0, green: 52.0/255.0, blue: 157.0/255.0, alpha: 1.0)
 
    static var litecoinWhite: UIColor {
      return .white
    }
    
    static var litecoinGray: UIColor { //F1F1F1
      return #colorLiteral(red: 0.9450980392, green: 0.9450980392, blue: 0.9450980392, alpha: 1)
    }
      
    static var litecoinSilver: UIColor { //A6A9AA
      return #colorLiteral(red: 0.6509803922, green: 0.662745098, blue: 0.6666666667, alpha: 1)
    }
    
    static var litecoinDarkSilver: UIColor { //4D4D4E
      return #colorLiteral(red: 0.3019607843, green: 0.3019607843, blue: 0.3058823529, alpha: 1)
    }
    
    static var liteWalletBlue: UIColor { //345D9D
      return #colorLiteral(red: 0.2039215686, green: 0.3647058824, blue: 0.6156862745, alpha: 1)
    }
    
    static var litecoinOrange: UIColor { // FE5F55
      return #colorLiteral(red: 0.9960784314, green: 0.3725490196, blue: 0.3333333333, alpha: 1)
    }
    
    static var litecoinGreen: UIColor { //179E27
      return #colorLiteral(red: 0.09019607843, green: 0.6196078431, blue: 0.1529411765, alpha: 1)
    }
    // MARK: Buttons
    static var primaryButton: UIColor {
        return #colorLiteral(red: 0.2980392157, green: 0.5960784314, blue: 0.9882352941, alpha: 1)  //UIColor(red: 76.0/255.0, green: 152.0/255.0, blue: 252.0/255.0, alpha: 1.0)
    }

    static var primaryText: UIColor {
        return .white
    }

    static var secondaryButton: UIColor {
        return #colorLiteral(red: 0.9607843137, green: 0.968627451, blue: 0.9803921569, alpha: 1) //UIColor(red: 245.0/255.0, green: 247.0/255.0, blue: 250.0/255.0, alpha: 1.0)
    }

    static var secondaryBorder: UIColor {
        return #colorLiteral(red: 0.8352941176, green: 0.8549019608, blue: 0.8784313725, alpha: 1) //UIColor(red: 213.0/255.0, green: 218.0/255.0, blue: 224.0/255.0, alpha: 1.0)
    }

    static var darkText: UIColor {
        return #colorLiteral(red: 0.137254902, green: 0.1450980392, blue: 0.1490196078, alpha: 1) //UIColor(red: 35.0/255.0, green: 37.0/255.0, blue: 38.0/255.0, alpha: 1.0)
    }

    static var darkLine: UIColor {
        return #colorLiteral(red: 0.1411764706, green: 0.137254902, blue: 0.1490196078, alpha: 1) //UIColor(red: 36.0/255.0, green: 35.0/255.0, blue: 38.0/255.0, alpha: 1.0)
    }

    static var secondaryShadow: UIColor {
        return UIColor(red: 213.0/255.0, green: 218.0/255.0, blue: 224.0/255.0, alpha: 1.0)
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
      return #colorLiteral(red: 0.5333333333, green: 0.5333333333, blue: 0.5333333333, alpha: 1) //UIColor(white: 136.0/255.0, alpha: 1.0)
    }
  
    static var grayTextTint: UIColor {
      return UIColor(red: 163.0/255.0, green: 168.0/255.0, blue: 173.0/255.0, alpha: 1.0)
    }
  
    static var secondaryGrayText: UIColor {
      return UIColor(red: 101.0/255.0, green: 105.0/255.0, blue: 110.0/255.0, alpha: 1.0)
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
  
    // MARK: Gradient
    static var gradientStart: UIColor {
        return UIColor(red: 131.0/255.0, green: 175.0/255.0, blue: 224.0/255.0, alpha: 1.0)
    }

    static var gradientEnd: UIColor {
        return UIColor(red: 118.0/255.0, green: 126.0/255.0, blue: 227.0/255.0, alpha: 1.0)
    }
 
    static var whiteTint: UIColor {
        return UIColor(red: 245.0/255.0, green: 247.0/255.0, blue: 250.0/255.0, alpha: 1.0)
    }

    static var transparentWhite: UIColor {
        return UIColor(white: 1.0, alpha: 0.3)
    }

    static var transparentBlack: UIColor {
        return UIColor(white: 0.0, alpha: 0.3)
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
} 
