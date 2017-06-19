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

class TransactionTableViewCell : UITableViewCell, Subscriber {

    //MARK: - Public
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
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

    func setTransaction(_ transaction: Transaction, isBtcSwapped: Bool, rate: Rate, maxDigits: Int, isSyncing: Bool) {
        self.transaction = transaction
        self.transactionLabel.attributedText = transaction.descriptionString(isBtcSwapped: isBtcSwapped, rate: rate, maxDigits: maxDigits)
        status.text = transaction.status
        comment.text = transaction.comment
        timestamp.text = transaction.timeSince
        availability.text = transaction.shouldDisplayAvailableToSpend ? S.Transaction.available : ""
        status.isHidden = isSyncing
    }

    let container = RoundedContainer()

    //MARK: - Private
    private let transactionLabel = UILabel()
    private let status = UILabel(font: UIFont.customBody(size: 13.0))
    private let comment = UILabel.wrapping(font: UIFont.customBody(size: 13.0))
    private let timestamp = UILabel(font: UIFont.customMedium(size: 13.0))
    private let shadowView = MaskedShadow()
    private let innerShadow = UIView()
    private let topPadding: CGFloat = 19.0
    private var style: TransactionCellStyle = .first
    private var transaction: Transaction?
    private let availability = UILabel(font: .customBold(size: 13.0), color: .cameraGuidePositive)

    private func setupViews() {
        addSubviews()
        addConstraints()
        setupStyle()
    }

    private func addSubviews() {
        contentView.addSubview(shadowView)
        contentView.addSubview(container)
        container.addSubview(innerShadow)
        container.addSubview(transactionLabel)
        container.addSubview(status)
        container.addSubview(comment)
        container.addSubview(timestamp)
        container.addSubview(availability)
    }

    private func addConstraints() {
        shadowView.constrain(toSuperviewEdges: UIEdgeInsets(top: 0, left: C.padding[2], bottom: 0, right: -C.padding[2]))
        container.constrain(toSuperviewEdges: UIEdgeInsets(top: 0, left: C.padding[2], bottom: 0, right: -C.padding[2]))
        innerShadow.constrainBottomCorners(sidePadding: 0, bottomPadding: 0)
        innerShadow.constrain([
            innerShadow.constraint(.height, constant: 1.0) ])
        transactionLabel.constrain([
            transactionLabel.constraint(.leading, toView: container, constant: C.padding[2]),
            transactionLabel.constraint(.top, toView: container, constant: topPadding),
            transactionLabel.trailingAnchor.constraint(lessThanOrEqualTo: timestamp.leadingAnchor, constant: -C.padding[1]) ])
        timestamp.setContentCompressionResistancePriority(UILayoutPriorityRequired, for: .horizontal)
        timestamp.constrain([
            timestamp.constraint(.trailing, toView: container, constant: -C.padding[2]),
            timestamp.constraint(.top, toView: container, constant: topPadding) ])
        comment.constrain([
            comment.constraint(.leading, toView: container, constant: C.padding[2]),
            comment.constraint(toBottom: transactionLabel, constant: C.padding[1]),
            comment.trailingAnchor.constraint(lessThanOrEqualTo: timestamp.leadingAnchor, constant: -C.padding[1]) ])
        status.constrain([
            status.constraint(.leading, toView: container, constant: C.padding[2]),
            status.constraint(toBottom: comment, constant: C.padding[1]),
            status.constraint(.trailing, toView: container, constant: -C.padding[2]) ])
        availability.constrain([
            availability.leadingAnchor.constraint(equalTo: status.leadingAnchor),
            availability.topAnchor.constraint(equalTo: status.bottomAnchor),
            availability.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -C.padding[2]) ])
    }

    private func setupStyle() {
        backgroundColor = .clear

        comment.textColor = .darkText
        status.textColor = .darkText
        timestamp.textColor = .grayTextTint

        shadowView.backgroundColor = .clear
        shadowView.layer.shadowColor = UIColor.black.cgColor
        shadowView.layer.shadowOpacity = 0.5
        shadowView.layer.shadowRadius = 4.0
        shadowView.layer.shadowOffset = CGSize(width: 0, height: 0)

        innerShadow.backgroundColor = .secondaryShadow

        transactionLabel.numberOfLines = 0
        transactionLabel.lineBreakMode = .byWordWrapping

    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        //intentional noop for now
        //The default selected state doesn't play nicely
        //with this custom cell
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        guard selectionStyle != .none else { container.backgroundColor = .white; return }
        container.backgroundColor = highlighted ? .secondaryShadow : .white
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
