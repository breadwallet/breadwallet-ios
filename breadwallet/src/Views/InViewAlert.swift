//
//  InViewAlert.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-12-03.
//  Copyright © 2016-2019 Breadwinner AG. All rights reserved.
//

import UIKit

enum InViewAlertType {
    case primary
    case secondary
}

private let arrowHeight: CGFloat = 8.0
private let arrowWidth: CGFloat = 16.0

class InViewAlert: UIView {

    var heightConstraint: NSLayoutConstraint?
    var isExpanded = false
    var contentView: UIView? {
        didSet {
            guard let view = contentView else { return }
            addSubview(view)
            view.constrain(toSuperviewEdges: UIEdgeInsets(top: arrowHeight, left: 0, bottom: 0, right: 0))
        }
    }
    var arrowXLocation: CGFloat?
    static var arrowSize: CGSize {
        return CGSize(width: arrowWidth, height: arrowHeight)
    }

    var height: CGFloat {
        switch type {
        case .primary:
            return 72.0
        case .secondary:
            return 81.0
        }
    }

    init(type: InViewAlertType) {
        self.type = type
        super.init(frame: .zero)
        setupSubViews()
    }

    func toggle() {
        heightConstraint?.constant = isExpanded ? 0.0 : height
    }

    private let type: InViewAlertType

    private func setupSubViews() {
        contentMode = .redraw
        backgroundColor = .clear
    }

    override func draw(_ rect: CGRect) {
        let background = UIBezierPath(rect: rect.offsetBy(dx: 0, dy: arrowHeight))
        fillColor.setFill()
        background.fill()

        let context = UIGraphicsGetCurrentContext()
        let center = arrowXLocation != nil ? arrowXLocation! : rect.width/2.0

        let triangle = CGMutablePath()
        triangle.move(to: CGPoint(x: center - arrowWidth/2.0 + 0.5, y: arrowHeight + 0.5))
        triangle.addLine(to: CGPoint(x: center + 0.5, y: 0.5))
        triangle.addLine(to: CGPoint(x: center + arrowWidth/2.0 + 0.5, y: arrowHeight + 0.5))
        triangle.closeSubpath()
        context?.setLineJoin(.miter)
        context?.setFillColor(fillColor.cgColor)
        context?.addPath(triangle)
        context?.fillPath()

        //Add Gray border for secondary style
        if type == .secondary {
            let topBorder = CGMutablePath()
            topBorder.move(to: CGPoint(x: 0, y: arrowHeight))
            topBorder.addLine(to: CGPoint(x: center - arrowWidth/2.0 + 0.5, y: arrowHeight + 0.5))
            topBorder.addLine(to: CGPoint(x: center + 0.5, y: 0.5))
            topBorder.addLine(to: CGPoint(x: center + arrowWidth/2.0 + 0.5, y: arrowHeight + 0.5))
            topBorder.addLine(to: CGPoint(x: rect.width + 0.5, y: arrowHeight + 0.5))
            context?.setLineWidth(1.0)
            context?.setStrokeColor(UIColor.secondaryShadow.cgColor)
            context?.addPath(topBorder)
            context?.strokePath()
        }
    }

    private var fillColor: UIColor {
        switch type {
        case .primary:
            return .primaryButton
        case .secondary:
            return .grayBackgroundTint
        }
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("This class does not support NSCoding")
    }
}
