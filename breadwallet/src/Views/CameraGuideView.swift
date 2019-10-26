//
//  CameraGuideView.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-12-13.
//  Copyright © 2016-2019 Breadwinner AG. All rights reserved.
//

import UIKit

private let guideSize: CGFloat = 64.0
private let lineWidth: CGFloat = 8.0

enum CameraGuideState {

    case normal, positive, negative

    var color: UIColor {
        switch self {
        case .normal: return .darkLine
        case .negative: return .cameraGuideNegative
        case .positive: return .cameraGuidePositive
        }
    }
}

class CameraGuideView: UIView {

    var state: CameraGuideState = .normal {
        didSet {
            setNeedsDisplay()
        }
    }

    init() {
        super.init(frame: .zero)
        backgroundColor = .clear
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }

        //top left
        context.addLineThrough([
            (0 + lineWidth/2.0, guideSize),
            (0 + lineWidth/2.0, 0 + lineWidth/2.0),
            (guideSize, 0 + lineWidth/2.0) ])

        //top right
        context.addLineThrough([
            (rect.maxX - guideSize, 0 + lineWidth/2.0),
            (rect.maxX - lineWidth/2.0, 0 + lineWidth/2.0),
            (rect.maxX - lineWidth/2.0, guideSize) ])

        //bottom right
        context.addLineThrough([
            (rect.maxX - lineWidth/2.0, rect.maxY - guideSize),
            (rect.maxY - lineWidth/2.0, rect.maxY - lineWidth/2.0),
            (rect.maxX - guideSize, rect.maxY - lineWidth/2.0) ])

        //bottom left
        context.addLineThrough([
            (lineWidth/2.0, rect.maxY - guideSize),
            (lineWidth/2.0, rect.maxY - lineWidth/2.0),
            (guideSize, rect.maxY - lineWidth/2.0) ])

        state.color.setStroke()
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setLineWidth(lineWidth)
        context.strokePath()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
