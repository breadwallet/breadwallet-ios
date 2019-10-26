//
//  StatusPip.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2017-12-22.
//  Copyright © 2016-2019 Breadwinner AG. All rights reserved.
//

import UIKit

class StatusPip: UIView {
    
    // MARK: Vars
    
    enum State {
        case off
        case on
        case flashing
    }
    
    var state: State {
        didSet {
            let color: UIColor = (state == .off) ? offColor : tintColor
            pipLayer.fillColor = color.cgColor
            
            if state == .flashing {
                pipLayer.add(flashingAnimation, forKey: flashingAnimationKey)
            } else {
                pipLayer.removeAnimation(forKey: flashingAnimationKey)
            }
        }
    }

    private let pipLayer = CAShapeLayer()
    
    private let flashingAnimationKey = "flashing"
    private var flashingAnimation: CABasicAnimation {
        let animation = CABasicAnimation(keyPath: "fillColor")
        
        animation.fromValue = tintColor.withAlphaComponent(0.05).cgColor
        animation.toValue = tintColor.withAlphaComponent(0.4).cgColor
        animation.duration = 1.0
        animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeIn)
        animation.repeatCount = Float.greatestFiniteMagnitude
        animation.autoreverses = true
        
        return animation
    }
    
    private let offColor: UIColor
    
    // MARK: Init

    init(onColor: UIColor = .statusIndicatorActive, offColor: UIColor = .grayBackground) {
        self.state = .off
        self.offColor = offColor
        super.init(frame: .zero)
        self.tintColor = onColor
        setup()
    }
    
    private func setup() {
        pipLayer.frame = bounds
        pipLayer.fillColor = offColor.cgColor
        pipLayer.lineWidth = 0.0
        layer.addSublayer(pipLayer)
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
        pipLayer.frame = bounds
        pipLayer.path = UIBezierPath(roundedRect: pipLayer.frame, cornerRadius: pipLayer.frame.height / 2.0).cgPath
    }
}
