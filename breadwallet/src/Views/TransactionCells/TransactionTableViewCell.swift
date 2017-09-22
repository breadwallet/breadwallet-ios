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

private let timestampRefreshRate: TimeInterval = 10.0

class TransactionTableViewCell : UITableViewCell, Subscriber {

    private class TransactionTableViewCellWrapper {
        weak var target: TransactionTableViewCell?
        init(target: TransactionTableViewCell) {
            self.target = target
        }

        @objc func timerDidFire() {
            target?.updateTimestamp()
        }
    }

    //MARK: - Public
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    deinit {
        timer?.invalidate()
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
        transactionLabel.attributedText = transaction.descriptionString(isBtcSwapped: isBtcSwapped, rate: rate, maxDigits: maxDigits)
        address.text = String(format: transaction.direction.addressTextFormat, transaction.toAddress ?? "")
        status.text = transaction.status
        comment.text = transaction.comment
        availability.text = transaction.shouldDisplayAvailableToSpend ? S.Transaction.available : ""

        if transaction.status == S.Transaction.complete {
            status.isHidden = false
        } else {
            status.isHidden = isSyncing
        }

        let timestampInfo = transaction.timeSince
        timestamp.text = timestampInfo.0
        if timestampInfo.1 {
            timer = Timer.scheduledTimer(timeInterval: timestampRefreshRate, target: TransactionTableViewCellWrapper(target: self), selector: NSSelectorFromString("timerDidFire"), userInfo: nil, repeats: true)
        } else {
            timer?.invalidate()
        }
        timestamp.isHidden = !transaction.isValid

        let identity: CGAffineTransform = .identity
        if transaction.direction == .received {
            arrow.transform = identity.rotated(by: π/2.0)
            arrow.tintColor = .txListGreen
        } else {
            arrow.transform = identity.rotated(by: 3.0*π/2.0)
            arrow.tintColor = .cameraGuideNegative
        }
    }

    let container = RoundedContainer()

    //MARK: - Private
    private let transactionLabel = UILabel()
    private let address = UILabel(font: UIFont.customBody(size: 13.0))
    private let status = UILabel(font: UIFont.customBody(size: 13.0))
    private let comment = UILabel.wrapping(font: UIFont.customBody(size: 13.0))
    private let timestamp = UILabel(font: UIFont.customMedium(size: 13.0))
    private let shadowView = MaskedShadow()
    private let innerShadow = UIView()
    private let topPadding: CGFloat = 19.0
    private var style: TransactionCellStyle = .first
    private var transaction: Transaction?
    private let availability = UILabel(font: .customBold(size: 13.0), color: .txListGreen)
    private var timer: Timer? = nil
    private let arrow = UIImageView(image: #imageLiteral(resourceName: "CircleArrow").withRenderingMode(.alwaysTemplate))

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
        container.addSubview(arrow)
        container.addSubview(address)
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
        arrow.constrain([
            arrow.trailingAnchor.constraint(equalTo: timestamp.leadingAnchor, constant: -4.0),
            arrow.centerYAnchor.constraint(equalTo: timestamp.centerYAnchor),
            arrow.heightAnchor.constraint(equalToConstant: 14.0),
            arrow.widthAnchor.constraint(equalToConstant: 14.0)])
        transactionLabel.constrain([
            transactionLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: C.padding[2]),
            transactionLabel.constraint(.top, toView: container, constant: topPadding),
            transactionLabel.trailingAnchor.constraint(lessThanOrEqualTo: timestamp.leadingAnchor, constant: -C.padding[1]) ])
        timestamp.setContentCompressionResistancePriority(UILayoutPriority.required, for: .horizontal)
        timestamp.constrain([
            timestamp.constraint(.trailing, toView: container, constant: -C.padding[2]),
            timestamp.constraint(.top, toView: container, constant: topPadding) ])

        address.constrain([
            address.leadingAnchor.constraint(equalTo: transactionLabel.leadingAnchor),
            address.topAnchor.constraint(equalTo: transactionLabel.bottomAnchor),
            address.trailingAnchor.constraint(lessThanOrEqualTo: timestamp.leadingAnchor, constant: -C.padding[4])])
        address.setContentCompressionResistancePriority(UILayoutPriority.defaultLow, for: .horizontal)

        comment.constrain([
            comment.constraint(.leading, toView: container, constant: C.padding[2]),
            comment.constraint(toBottom: address, constant: C.padding[1]),
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

        address.lineBreakMode = .byTruncatingMiddle
        address.numberOfLines = 1

    }

    func updateTimestamp() {
        guard let tx = transaction else { return }
        let timestampInfo = tx.timeSince
        timestamp.text = timestampInfo.0
        if !timestampInfo.1 {
            timer?.invalidate()
        }
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
