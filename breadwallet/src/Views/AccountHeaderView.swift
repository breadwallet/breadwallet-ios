//
//  AccountHeaderView.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-11-16.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

class AccountHeaderView: UIView {

    override func draw(_ rect: CGRect) {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let colors = [UIColor.gradientStart.cgColor, UIColor.gradientEnd.cgColor] as CFArray
        let locations: [CGFloat] = [0.0, 1.0]
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations)

        let context = UIGraphicsGetCurrentContext()
        context?.drawLinearGradient(gradient!, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: rect.width, y: 0.0), options: CGGradientDrawingOptions(rawValue: 0))
    }
}
