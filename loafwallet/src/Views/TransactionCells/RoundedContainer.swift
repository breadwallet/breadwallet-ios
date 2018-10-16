    
//  RoundedContainer.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-11-17.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

class RoundedContainer: UIView {

    var style: TransactionCellStyle = .middle {
        didSet {
            setNeedsLayout()
        }
    }

    override func layoutSubviews() {
        let maskLayer = CAShapeLayer()
        let corners: UIRectCorner
        switch style {
        case .first:
            corners = [.topLeft, .topRight]
        case .last:
            corners = [.bottomLeft, .bottomRight]
        case .single:
            corners = .allCorners
        case .middle:
            corners = []
        }
        maskLayer.path = UIBezierPath(roundedRect: bounds, byRoundingCorners: corners, cornerRadii: CGSize(width: 4.0, height: 4.0)).cgPath
        layer.mask = maskLayer
    }

}
