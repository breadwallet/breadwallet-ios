//
//  ShadowView.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-11-17.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

class MaskedShadow: UIView {

    var style: TransactionCellStyle = .middle {
        didSet {
            setNeedsLayout()
        }
    }
    private let shadowSize: CGFloat = 8.0

    override func layoutSubviews() {

        guard style != .single else {
            layer.mask = nil
            layer.shadowPath = UIBezierPath(rect: bounds).cgPath
            return
        }

        var shadowRect = bounds.insetBy(dx: 0, dy: -shadowSize)
        var maskRect = bounds.insetBy(dx: -shadowSize, dy: 0)

        if style == .first {
            maskRect.origin.y -= shadowSize
            maskRect.size.height += shadowSize
            shadowRect.origin.y += shadowSize
        }

        if style == .last {
            maskRect.size.height += shadowSize
            shadowRect.size.height -= shadowSize
        }

        let maskLayer = CAShapeLayer()
        maskLayer.path = UIBezierPath(rect: maskRect).cgPath
        layer.mask = maskLayer
        layer.shadowPath = UIBezierPath(rect: shadowRect).cgPath
    }
}
