//
//  GradientCircle.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-11-22.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

class GradientCircle: UIView {

    private let startColor: CGColor
    private let endColor: CGColor

    static let defaultSize: CGFloat = 64.0

    init(startColor: UIColor, endColor: UIColor) {
        self.startColor = startColor.cgColor
        self.endColor = endColor.cgColor
        super.init(frame: CGRect())
        backgroundColor = .clear
    }

    override func draw(_ rect: CGRect) {
        drawGradient(rect)
        maskToCircle(rect)
    }

    private func drawGradient(_ rect: CGRect) {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let colors = [startColor, endColor] as CFArray
        let locations: [CGFloat] = [0.0, 1.0]
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations)
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.drawLinearGradient(gradient!, start: .zero, end: CGPoint(x: rect.width, y: 0.0), options: [])
    }

    private func maskToCircle(_ rect: CGRect) {
        let maskLayer = CAShapeLayer()
        maskLayer.path = UIBezierPath(ovalIn: rect).cgPath
        layer.mask = maskLayer
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
