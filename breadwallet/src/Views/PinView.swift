//
//  PinView.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-28.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

class PinView: UIView {

    private let store: Store
    private let unFilled = (0...5).map { _ in Circle(color: .borderGray) }
    private let filled = (0...5).map { _ in Circle(color: .black) }

    init(store: Store) {
        self.store = store
        super.init(frame: CGRect())
        setupSubviews()
    }

    func fill(_ number: Int) {
        filled.enumerated().forEach { index, circle in
            circle.isHidden = index > number-1
        }
    }

    func shake() {
        let translation = CAKeyframeAnimation(keyPath: "transform.translation.x");
        translation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
        translation.values = [-5, 5, -5, 5, -3, 3, -2, 2, 0]

        let rotation = CAKeyframeAnimation(keyPath: "transform.rotation.y");
        rotation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)

        rotation.values = [-5, 5, -5, 5, -3, 3, -2, 2, 0].map {
            self.toRadian(value: $0)
        }
        let shakeGroup: CAAnimationGroup = CAAnimationGroup()
        shakeGroup.animations = [translation, rotation]
        shakeGroup.duration = 0.6
        self.layer.add(shakeGroup, forKey: "shakeIt")
    }

    private func toRadian(value: Int) -> CGFloat {
        return CGFloat(Double(value) / 180.0 * M_PI)
    }

    private func setupSubviews() {
        addCircleContraints(unFilled)
        addCircleContraints(filled)
        filled.forEach { $0.isHidden = true }
    }

    private func addCircleContraints(_ circles: [Circle]) {
        circles.enumerated().forEach { index, circle in
            addSubview(circle)
            let leadingConstraint: NSLayoutConstraint
            if index == 0 {
                leadingConstraint = circle.constraint(.leading, toView: self, constant: 0.0)
            } else {
                leadingConstraint = NSLayoutConstraint(item: circle, attribute: .leading, relatedBy: .equal, toItem: circles[index - 1], attribute: .trailing, multiplier: 1.0, constant: 8.0)
            }
            circle.constrain([
                    circle.constraint(.width, constant: 16.0),
                    circle.constraint(.height, constant: 16.0),
                    circle.constraint(.centerY, toView: self, constant: nil),
                    leadingConstraint
                ])
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
