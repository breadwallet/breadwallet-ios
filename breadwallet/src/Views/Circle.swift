//
//  Circle.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-24.
//  Copyright © 2016-2019 Breadwinner AG. All rights reserved.
//

import UIKit

class Circle: UIView {

    private let color: UIColor
    private let style: CircleStyle
    static let defaultSize: CGFloat = 64.0

    init(color: UIColor, style: CircleStyle) {
        self.color = color
        self.style = style
        super.init(frame: .zero)
        backgroundColor = .clear
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        switch style {
        case .filled:
            context.addEllipse(in: rect)
            context.setFillColor(color.cgColor)
            context.fillPath()
        case .unfilled:
            context.addEllipse(in: rect.insetBy(dx: 0.5, dy: 0.5))
            context.setLineWidth(1.0)
            context.setStrokeColor(color.cgColor)
            context.strokePath()
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

enum CircleStyle {
    case filled
    case unfilled
}

class ClearCircle: UIView {

    private var didLayout = false
    private let style: CircleStyle

    init(style: CircleStyle) {
        self.style = style
        super.init(frame: .zero)
        backgroundColor = .clear
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !didLayout else { return }
        didLayout = true

        let centerRect = CGRect(x: 0.0, y: 0.0, width: bounds.width - 8.0, height: bounds.height)

        let overlayPath = UIBezierPath(rect: bounds)
        let transparentPath = UIBezierPath(ovalIn: centerRect)
        overlayPath.append(transparentPath)
        overlayPath.usesEvenOddFillRule = true
        let fillLayer = CAShapeLayer()
        fillLayer.path = overlayPath.cgPath
        fillLayer.fillRule = CAShapeLayerFillRule.evenOdd
        fillLayer.fillColor = UIColor.darkBackground.cgColor
        layer.sublayers?.forEach {
            $0.removeFromSuperlayer()
        }
        layer.addSublayer(fillLayer)

        if style == .unfilled {
            let innerCircle = UIBezierPath(ovalIn: centerRect.insetBy(dx: 1.0, dy: 1.0))
            let circleLayer = CAShapeLayer()
            circleLayer.path = innerCircle.cgPath
            circleLayer.fillColor = UIColor.darkBackground.cgColor
            layer.addSublayer(circleLayer)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}
