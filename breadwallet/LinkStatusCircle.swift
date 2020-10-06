//
//  LinkStatusCircle.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2018-07-29.
//  Copyright © 2018-2019 Breadwinner AG. All rights reserved.
//

import UIKit

class LinkStatusCircle: UIView {

    private let circleLayer = CAShapeLayer()
    private let checkLayer = CAShapeLayer()
    private var hasPerformedLayout = false
    private let originalCheckSize: CGFloat = 96.0
    private let colour: UIColor
    private let checkBoxAnimationDuration: TimeInterval = 0.4
    private let animationDuration: TimeInterval = 2.0
    private let animationDurationOffset: TimeInterval = 0.5

    init(colour: UIColor = C.defaultTintColor) {
        self.colour = colour
        super.init(frame: .zero)
    }

    override func layoutSubviews() {
        guard !hasPerformedLayout else { hasPerformedLayout = true; return }
        clipsToBounds = false
        backgroundColor = .clear

        let path = UIBezierPath(arcCenter: .zero, radius: bounds.width/2.0, startAngle: .pi/2.0, endAngle: (.pi/2.0) - .pi * 2.0, clockwise: false)
        circleLayer.path = path.cgPath
        circleLayer.fillColor = UIColor.clear.cgColor
        circleLayer.strokeColor = colour.cgColor
        circleLayer.lineWidth = 1.0
        circleLayer.strokeEnd = 0.0
        circleLayer.position = bounds.center
        layer.addSublayer(circleLayer)

        let check = UIBezierPath()
        let scaleFactor = (bounds.width)/originalCheckSize
        check.move(to: CGPoint(x: 32.5*scaleFactor, y: 47.0*scaleFactor))
        check.addLine(to: CGPoint(x: 43.0*scaleFactor, y: 57.0*scaleFactor))
        check.addLine(to: CGPoint(x: 63*scaleFactor, y: 37.4*scaleFactor))

        checkLayer.path = check.cgPath
        checkLayer.lineWidth = 2.0
        checkLayer.strokeColor = UIColor.white.cgColor
        checkLayer.strokeColor = colour.cgColor
        checkLayer.fillColor = UIColor.clear.cgColor
        checkLayer.strokeEnd = 0.0
        checkLayer.lineCap = CAShapeLayerLineCap.round
        checkLayer.lineJoin = CAShapeLayerLineJoin.round

        layer.addSublayer(checkLayer)
    }

    func drawCircleWithRepeat() {
        circleLayer.strokeEnd = 1.0
        circleLayer.add(strokeEndAnimation(), forKey: "strokeEnd")
        circleLayer.add(strokeStartAnimation(), forKey: "strokeStart")
        circleLayer.add(rotationAnimation(), forKey: "transform.rotation.z")
    }
    
    func drawCircle() {
        circleLayer.strokeEnd = 1.0
    }

    func drawCheckBox() {

        circleLayer.removeAnimation(forKey: "strokeEnd")
        circleLayer.removeAnimation(forKey: "strokeStart")
        circleLayer.removeAnimation(forKey: "transform.rotation.z")

        let checkAnimation = CABasicAnimation(keyPath: "strokeEnd")
        checkAnimation.fromValue = 0.0
        checkAnimation.toValue = 1.0
        checkAnimation.fillMode = CAMediaTimingFillMode.forwards
        checkAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeIn)
        checkAnimation.duration = checkBoxAnimationDuration
        checkLayer.strokeEnd = 1.0
        checkLayer.add(checkAnimation, forKey: "drawCheck")
    }

    private func strokeEndAnimation() -> CAAnimation {
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.fromValue = 0
        animation.toValue = 1
        animation.duration = animationDuration
        animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)

        let group = CAAnimationGroup()
        group.duration = animationDuration + animationDurationOffset
        group.repeatCount = MAXFLOAT
        group.animations = [animation]
        return group
    }

    private func strokeStartAnimation() -> CAAnimation {
        let animation = CABasicAnimation(keyPath: "strokeStart")
        animation.beginTime = 0.5
        animation.fromValue = 0
        animation.toValue = 1
        animation.duration = animationDuration
        animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)

        let group = CAAnimationGroup()
        group.duration = animationDuration + animationDurationOffset
        group.repeatCount = MAXFLOAT
        group.animations = [animation]

        return group
    }

    private func rotationAnimation() -> CAAnimation {
        let animation = CABasicAnimation(keyPath: "transform.rotation.z")
        animation.fromValue = CGFloat.pi/2.0
        animation.toValue = (.pi/2.0) - .pi * 2.0
        animation.duration = animationDuration * 2.0
        animation.repeatCount = MAXFLOAT
        return animation
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
