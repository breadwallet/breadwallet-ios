//
//  LineLoadingView.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2019-07-08.
//  Copyright © 2019 breadwallet LLC. All rights reserved.
//

import UIKit

enum LineLoadingViewStyle {
    case chart
    case sync
    
    var color: UIColor {
        switch self {
        case .chart:
            return UIColor.white
        case .sync:
            return Theme.accent
        }
    }
}

class LineLoadingView: UIView {
    
    private var hasPerformedLayout = false
    private var lineLayer = CAShapeLayer()
    private let animationDuration: TimeInterval = 2.0
    private let animationDurationOffset: TimeInterval = 1.2
    private let colour: UIColor
    
    init(style: LineLoadingViewStyle) {
        self.colour = style.color
        super.init(frame: .zero)
    }
    
    override func layoutSubviews() {
        guard !hasPerformedLayout else { hasPerformedLayout = true; return }
        
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0.0, y: bounds.midY))
        path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.midY))
        lineLayer.path = path.cgPath
        lineLayer.strokeColor = colour.cgColor
        lineLayer.lineWidth = 1.0
        lineLayer.strokeEnd = 1.0
        layer.addSublayer(lineLayer)
        animate()
    }
    
    private func animate() {
        lineLayer.strokeEnd = 1.0
        lineLayer.add(strokeEndAnimation(), forKey: "strokeEnd")
        lineLayer.add(strokeStartAnimation(), forKey: "strokeStart")
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
        animation.beginTime = animationDurationOffset
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
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
