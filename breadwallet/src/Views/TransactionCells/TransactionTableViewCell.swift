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

class TransactionTableViewCell : UITableViewCell {

    private let transaction =   UILabel()
    private let status =        UILabel(font: UIFont.customBody(size: 13.0))
    private let comment =       UILabel.wrapping(font: UIFont.customBody(size: 13.0))
    private let timestamp =     UILabel(font: UIFont.customMedium(size: 13.0))
    private let container =     RoundedContainer()
    private let shadowView =    MaskedShadow()
    private let innerShadow =   UIView()

    private let topPadding: CGFloat = 19.0
    private var style: TransactionCellStyle = .first

    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    private func setupViews() {
        addSubviews()
        addConstraints()
        setupStyle()
    }

    private func addSubviews() {
        contentView.addSubview(shadowView)
        contentView.addSubview(container)
        container.addSubview(innerShadow)
        container.addSubview(transaction)
        container.addSubview(status)
        container.addSubview(comment)
        container.addSubview(timestamp)
    }

    private func addConstraints() {
        shadowView.constrain(toSuperviewEdges: UIEdgeInsets(top: 0, left: C.padding[2], bottom: 0, right: -C.padding[2]))
        container.constrain(toSuperviewEdges: UIEdgeInsets(top: 0, left: C.padding[2], bottom: 0, right: -C.padding[2]))
        innerShadow.constrainBottomCorners(sidePadding: 0, bottomPadding: 0)
        innerShadow.constrain([
                innerShadow.constraint(.height, constant: 1.0)
            ])
        transaction.constrain([
                transaction.constraint(.leading, toView: container, constant: C.padding[2]),
                transaction.constraint(.top, toView: container, constant: topPadding),
                NSLayoutConstraint(item: transaction, attribute: .trailing, relatedBy: .lessThanOrEqual, toItem: timestamp, attribute: .leading, multiplier: 1.0, constant: -C.padding[1])
            ])
        timestamp.constrain([
                timestamp.constraint(.trailing, toView: container, constant: -C.padding[2]),
                timestamp.constraint(.top, toView: container, constant: topPadding)
            ])
        status.constrain([
                status.constraint(.leading, toView: container, constant: C.padding[2]),
                status.constraint(toBottom: transaction, constant: C.padding[1]),
                status.constraint(.trailing, toView: container, constant: -C.padding[2])
            ])
        comment.constrain([
                comment.constraint(.leading, toView: container, constant: C.padding[2]),
                comment.constraint(toBottom: status, constant: C.padding[1]),
                NSLayoutConstraint(item: comment, attribute: .trailing, relatedBy: .lessThanOrEqual, toItem: timestamp, attribute: .leading, multiplier: 1.0, constant: -C.padding[1]),
                comment.constraint(.bottom, toView: container, constant: -C.padding[2])
            ])
    }

    private func setupStyle() {
        comment.textColor = .darkText
        status.textColor = .darkText
        timestamp.textColor = .grayTextTint

        shadowView.backgroundColor = .clear
        shadowView.layer.shadowColor = UIColor.black.cgColor
        shadowView.layer.shadowOpacity = 0.5
        shadowView.layer.shadowRadius = 4.0
        shadowView.layer.shadowOffset = CGSize(width: 0, height: 0)

        innerShadow.backgroundColor = .secondaryShadow
    }

    func setStyle(_ style: TransactionCellStyle) {
        container.style = style
        shadowView.style = style
        if style == .last || style == .single {
            innerShadow.isHidden = true
        } else {
            innerShadow.isHidden = false
        }
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        //intentional noop for now
        //The default selected state doesn't play nicely
        //with this custom cell
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        container.backgroundColor = highlighted ? .secondaryShadow : .white
    }

    func setTransaction(_ transaction: Transaction) {
        self.transaction.attributedText = transaction.descriptionString
        status.text = transaction.status
        comment.text = transaction.comment
        timestamp.text = transaction.timestampString
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
