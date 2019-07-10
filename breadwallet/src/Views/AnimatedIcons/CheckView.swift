//
//  CheckView.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-11-22.
//  Copyright © 2016-2019 Breadwinner AG. All rights reserved.
//

import UIKit

class CheckView: UIView, AnimatableIcon {

    func startAnimating() {
        let check = UIBezierPath()
        check.move(to: CGPoint(x: 32.5, y: 47.0))
        check.addLine(to: CGPoint(x: 43.0, y: 57.0))
        check.addLine(to: CGPoint(x: 63, y: 37.4))

        let shape = CAShapeLayer()
        shape.path = check.cgPath
        shape.lineWidth = 9.0
        shape.strokeColor = UIColor.white.cgColor
        shape.fillColor = UIColor.clear.cgColor
        shape.strokeStart = 0.0
        shape.strokeEnd = 0.0
        shape.lineCap = CAShapeLayerLineCap.round
        shape.lineJoin = CAShapeLayerLineJoin.round
        layer.addSublayer(shape)

        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.toValue = 1.0
        animation.isRemovedOnCompletion = false
        animation.fillMode = CAMediaTimingFillMode.forwards
        animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.default)
        animation.duration = 0.3

        shape.add(animation, forKey: nil)
    }

    func stopAnimating() {
        
    }
    
    override func draw(_ rect: CGRect) {

        let checkcircle = UIBezierPath()
        checkcircle.move(to: CGPoint(x: 47.76, y: -0))
        checkcircle.addCurve(to: CGPoint(x: 0, y: 47.76), controlPoint1: CGPoint(x: 21.38, y: -0), controlPoint2: CGPoint(x: 0, y: 21.38))
        checkcircle.addCurve(to: CGPoint(x: 47.76, y: 95.52), controlPoint1: CGPoint(x: 0, y: 74.13), controlPoint2: CGPoint(x: 21.38, y: 95.52))
        checkcircle.addCurve(to: CGPoint(x: 95.52, y: 47.76), controlPoint1: CGPoint(x: 74.14, y: 95.52), controlPoint2: CGPoint(x: 95.52, y: 74.13))
        checkcircle.addCurve(to: CGPoint(x: 47.76, y: -0), controlPoint1: CGPoint(x: 95.52, y: 21.38), controlPoint2: CGPoint(x: 74.14, y: -0))
        checkcircle.addLine(to: CGPoint(x: 47.76, y: -0))
        checkcircle.close()
        checkcircle.move(to: CGPoint(x: 47.99, y: 85.97))
        checkcircle.addCurve(to: CGPoint(x: 9.79, y: 47.76), controlPoint1: CGPoint(x: 26.89, y: 85.97), controlPoint2: CGPoint(x: 9.79, y: 68.86))
        checkcircle.addCurve(to: CGPoint(x: 47.99, y: 9.55), controlPoint1: CGPoint(x: 9.79, y: 26.66), controlPoint2: CGPoint(x: 26.89, y: 9.55))
        checkcircle.addCurve(to: CGPoint(x: 86.2, y: 47.76), controlPoint1: CGPoint(x: 69.1, y: 9.55), controlPoint2: CGPoint(x: 86.2, y: 26.66))
        checkcircle.addCurve(to: CGPoint(x: 47.99, y: 85.97), controlPoint1: CGPoint(x: 86.2, y: 68.86), controlPoint2: CGPoint(x: 69.1, y: 85.97))
        checkcircle.close()

        UIColor.white.setFill()
        checkcircle.fill()

        //This is the non-animated check left here for now as a reference
//        let check = UIBezierPath()
//        check.move(to: CGPoint(x: 30.06, y: 51.34))
//        check.addCurve(to: CGPoint(x: 30.06, y: 44.75), controlPoint1: CGPoint(x: 28.19, y: 49.52), controlPoint2: CGPoint(x: 28.19, y: 46.57))
//        check.addCurve(to: CGPoint(x: 36.9, y: 44.69), controlPoint1: CGPoint(x: 32, y: 42.87), controlPoint2: CGPoint(x: 35.03, y: 42.87))
//        check.addLine(to: CGPoint(x: 42.67, y: 50.3))
//        check.addLine(to: CGPoint(x: 58.62, y: 34.79))
//        check.addCurve(to: CGPoint(x: 65.39, y: 34.8), controlPoint1: CGPoint(x: 60.49, y: 32.98), controlPoint2: CGPoint(x: 63.53, y: 32.98))
//        check.addCurve(to: CGPoint(x: 65.46, y: 41.45), controlPoint1: CGPoint(x: 67.33, y: 36.68), controlPoint2: CGPoint(x: 67.33, y: 39.63))
//        check.addLine(to: CGPoint(x: 45.33, y: 61.02))
//        check.addCurve(to: CGPoint(x: 40.01, y: 61.02), controlPoint1: CGPoint(x: 43.86, y: 62.44), controlPoint2: CGPoint(x: 41.48, y: 62.44))
//        check.addLine(to: CGPoint(x: 30.06, y: 51.34))
//        check.close()
//        check.move(to: CGPoint(x: 30.06, y: 51.34))
//
//        UIColor.green.setFill()
//        check.fill()
    }
}
