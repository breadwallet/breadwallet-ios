//
//  DrawableCircle.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-05-24.
//  Copyright © 2017-2019 Breadwinner AG. All rights reserved.
//

import UIKit

class DrawableCircle: UIView {

    private let circleLayer = CAShapeLayer()
    private let checkLayer = CAShapeLayer()
    private var hasPerformedLayout = false
    private let originalCheckSize: CGFloat = 96.0
    private let animationDuration: TimeInterval = 0.4

    override func layoutSubviews() {
        guard !hasPerformedLayout else { hasPerformedLayout = true; return }
        clipsToBounds = false
        backgroundColor = .clear

        let path = UIBezierPath(arcCenter: bounds.center, radius: bounds.width/2.0, startAngle: .pi/2.0, endAngle: (.pi/2.0) - .pi * 2.0, clockwise: false)
        circleLayer.path = path.cgPath
        circleLayer.fillColor = UIColor.clear.cgColor
        circleLayer.strokeColor = C.defaultTintColor.cgColor
        circleLayer.lineWidth = 1.0
        circleLayer.opacity = 0
        layer.addSublayer(circleLayer)

        let check = UIBezierPath()
        let scaleFactor = (bounds.width)/originalCheckSize
        check.move(to: CGPoint(x: 32.5*scaleFactor, y: 47.0*scaleFactor))
        check.addLine(to: CGPoint(x: 43.0*scaleFactor, y: 57.0*scaleFactor))
        check.addLine(to: CGPoint(x: 63*scaleFactor, y: 37.4*scaleFactor))

        checkLayer.path = check.cgPath
        checkLayer.lineWidth = 2.0
        checkLayer.strokeColor = UIColor.white.cgColor
        checkLayer.strokeColor = C.defaultTintColor.cgColor
        checkLayer.fillColor = UIColor.clear.cgColor
        checkLayer.strokeEnd = 0.0
        checkLayer.lineCap = CAShapeLayerLineCap.round
        checkLayer.lineJoin = CAShapeLayerLineJoin.round
        layer.addSublayer(checkLayer)
    }

    func show() {
        let circleAnimation = CABasicAnimation(keyPath: "opacity")
        circleAnimation.duration = animationDuration
        circleAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeIn)
        circleAnimation.fromValue = 0.0
        circleAnimation.toValue = 1.0
        circleLayer.opacity = 1.0
        circleLayer.add(circleAnimation, forKey: "drawCircle")

        let checkAnimation = CABasicAnimation(keyPath: "strokeEnd")
        checkAnimation.fromValue = 0.0
        checkAnimation.toValue = 1.0
        checkAnimation.fillMode = CAMediaTimingFillMode.forwards
        checkAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeIn)
        checkAnimation.duration = animationDuration
        checkLayer.strokeEnd = 1.0
        checkLayer.add(checkAnimation, forKey: "drawCheck")
    }

}
