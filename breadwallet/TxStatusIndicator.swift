//
//  TxStatusIndicator.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2017-12-22.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

class TxStatusIndicator: UIView {

    var status: TxConfirmationStatus = .networkReceived {
        didSet {
            updateStatus()
        }
    }
    
    let size: CGFloat = 6.0
    private let padding: CGFloat = 4.0
    
    var width: CGFloat {
        return (size + padding) * 3
    }
    
    private var circles = [StatusCircle]()
    
    // MARK: Init
    
    init() {
        super.init(frame: .zero)
        setup()
    }
    
    private func setup() {
        for _ in 0..<3 {
            circles.append(StatusCircle(color: .blue))
        }
        
        addCircleContraints()
    }
    
    private func addCircleContraints() {
        circles.enumerated().forEach { index, circle in
            addSubview(circle)
            let leadingConstraint: NSLayoutConstraint?
            if index == 0 {
                leadingConstraint = circle.constraint(.leading, toView: self, constant: 0.0)
            } else {
                leadingConstraint = NSLayoutConstraint(item: circle,
                                                       attribute: .leading,
                                                       relatedBy: .equal,
                                                       toItem: circles[index - 1],
                                                       attribute: .trailing,
                                                       multiplier: 1.0,
                                                       constant: padding)
            }
            circle.constrain([
                circle.constraint(.width, constant: size),
                circle.constraint(.height, constant: size),
                circle.constraint(.centerY, toView: self, constant: nil),
                leadingConstraint ])
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: -
    
    func updateStatus() {
        let activeIndex = status.rawValue + 1 // first circle always on
        circles.enumerated().forEach { index, circle in
            if index == activeIndex {
                circle.state = .flashing
            } else if index < activeIndex {
                circle.state = .on
            } else {
                circle.state = .off
            }
        }
    }
}

