//
//  GradientView.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-11-22.
//  Copyright © 2016-2019 Breadwinner AG. All rights reserved.
//

import UIKit

protocol GradientDrawable {
    func drawGradient(_ rect: CGRect)
}

extension UIView {
    func drawGradient(_ rect: CGRect) {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let colors = [UIColor.gradientStart.cgColor, UIColor.gradientEnd.cgColor] as CFArray
        let locations: [CGFloat] = [0.0, 1.0]
        guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) else { return }
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: rect.width, y: 0.0), options: [])
    }

    func drawGradient(start: UIColor, end: UIColor, _ rect: CGRect) {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let colors = [start.cgColor, end.cgColor] as CFArray
        let locations: [CGFloat] = [0.0, 1.0]
        guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) else { return }
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: rect.width, y: 0.0), options: [])
    }
    
    func drawGradient(ends: UIColor, middle: UIColor, _ rect: CGRect) {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let colors = [ends.cgColor, middle.cgColor, ends.cgColor] as CFArray
        let locations: [CGFloat] = [0.0, 0.5, 1.0]
        guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) else { return }
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: rect.height), options: [])
    }
}

class GradientView: UIView {
    override func draw(_ rect: CGRect) {
        drawGradient(rect)
    }
}

class DoubleGradientView: UIView {
    override func draw(_ rect: CGRect) {
        drawGradient(ends: UIColor.white.withAlphaComponent(0.1), middle: UIColor.white.withAlphaComponent(0.6), rect)
    }
}
