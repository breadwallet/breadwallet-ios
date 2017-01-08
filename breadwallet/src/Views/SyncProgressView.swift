//
//  SyncProgressView.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-01-07.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

class SyncProgressView : UIView, GradientDrawable {

    let label = UILabel()

    init() {
        super.init(frame: .zero)
        addTopCorners()

        addSubview(label)
        label.constrain(toSuperviewEdges: nil)
    }

    override func layoutSubviews() {
        addTopCorners()
    }

    private func addTopCorners() {
        let path = UIBezierPath(roundedRect: bounds, byRoundingCorners: [.bottomLeft, .bottomRight], cornerRadii: CGSize(width: 6.0, height: 6.0)).cgPath
        let maskLayer = CAShapeLayer()
        maskLayer.path = path
        layer.mask = maskLayer
    }

    override func draw(_ rect: CGRect) {
        drawGradient(rect)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
