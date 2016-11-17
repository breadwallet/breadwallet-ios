//
//  TransactionTableViewCell.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-11-16.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

enum TransactionCellStyle {
    case first
    case middle
    case last
    case single
}

class ShadowView: UIView {

    var style: TransactionCellStyle = .middle
    private let shadowSize: CGFloat = 8.0
    override func layoutSubviews() {
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

class TransactionTableViewCell: UITableViewCell {

    private let transaction =   UILabel()
    private let status =        UILabel()
    private let comment =       UILabel()
    private let timestamp =     UILabel()
    private let card: ShadowView = {
        let view = ShadowView()
        view.backgroundColor = .white
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.5
        view.layer.shadowRadius = 4.0
        view.layer.shadowOffset = CGSize(width: 0, height: 0)

        return view
    }()
    private let innerShadow: UIView = {
        let view = UIView()
        view.backgroundColor = .secondaryShadow
        return view
    }()
    private var style: TransactionCellStyle = .first

    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    private func setupViews() {
        contentView.addSubview(card)
        card.constrain(toSuperviewEdges: UIEdgeInsets(top: 0, left: Constants.Padding.double, bottom: 0, right: -Constants.Padding.double))
        card.addSubview(innerShadow)
        innerShadow.constrainBottomCorners(sidePadding: 0, bottomPadding: 0)
        innerShadow.constrain([
                innerShadow.constraint(.height, constant: 1.0)
            ])
    }

    func setSytle(_ style: TransactionCellStyle) {
        card.style = style
        card.setNeedsLayout()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {

    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        card.backgroundColor = highlighted ? .secondaryShadow : .white
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
