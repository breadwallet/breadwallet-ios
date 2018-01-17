//
//  StatusCircle.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2017-12-22.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

class StatusCircle: UIView {
    
    // MARK: Vars
    
    enum State {
        case off
        case on
        case flashing
    }
    
    var state: State {
        didSet {
            let alpha: CGFloat = (state == .off) ? 0.25 : 1.0
            circleLayer.fillColor = color.withAlphaComponent(alpha).cgColor
            
            if state == .flashing {
                circleLayer.add(flashingAnimation, forKey: flashingAnimationKey)
            } else {
                circleLayer.removeAnimation(forKey: flashingAnimationKey)
            }
        }
    }

    private var color: UIColor
    private let circleLayer = CAShapeLayer()
    
    private let flashingAnimationKey = "flashing"
    private var flashingAnimation: CABasicAnimation {
        let animation = CABasicAnimation(keyPath: "opacity")
        
        animation.fromValue = 1.0
        animation.toValue = 0.25
        animation.duration = 1.0
        animation.repeatCount = Float.greatestFiniteMagnitude
        animation.autoreverses = true
        
        return animation
    }
    
    // MARK: Init

    init(color: UIColor) {
        self.color = color
        self.state = .off
        super.init(frame: .zero)
        setup()
    }
    
    private func setup() {
        circleLayer.frame = bounds
        circleLayer.fillColor = color.cgColor
        circleLayer.lineWidth = 0.0
        layer.addSublayer(circleLayer)
        backgroundColor = .clear
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        updateShapeLayer()
    }
    
    private func updateShapeLayer() {
        circleLayer.frame = bounds
        circleLayer.path = UIBezierPath(ovalIn: circleLayer.frame).cgPath
    }
}
