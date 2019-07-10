//
//  GradientCircle.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-11-22.
//  Copyright © 2016-2019 Breadwinner AG. All rights reserved.
//

import UIKit

class GradientCircle: UIView, GradientDrawable {

    static let defaultSize: CGFloat = 64.0

    init() {
        super.init(frame: CGRect())
        backgroundColor = .clear
    }

    override func draw(_ rect: CGRect) {
        drawGradient(rect)
        maskToCircle(rect)
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
