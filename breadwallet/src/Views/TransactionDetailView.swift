//
//  TransactionDetailView.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-02-09.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

class TransactionDetailView : UIView {

    //MARK: - Public
    init(currency: Currency, rate: Rate) {
        self.currency = currency
        self.rate = rate
        super.init(frame: .zero)
        setup()
    }

    var transaction: Transaction? {
        didSet {
            guard let transaction = transaction else { return }
            timestamp.text = transaction.longTimestamp
            amount.text = "\(transaction.direction.rawValue) \(transaction.amountDescription(currency: currency, rate: rate))"
            address.text = "\(transaction.direction.preposition) an address"
            status.text = transaction.longStatus
            comments.text = "Comments will go here"
            amountDetails.text = transaction.amountDetails(currency: currency, rate: rate)
            addressHeader.text = "To" //Should this be from sometimes?
            fullAddress.text = transaction.toAddress ?? ""
        }
    }

    var closeCallback: (() -> Void)? {
        didSet {
            header.closeCallback = closeCallback
        }
    }

    //MARK: - Private
    private let currency: Currency
    private let rate: Rate

    private func setup() {
        backgroundColor = .white
        addSubview(header)
        addSubview(timestamp)
        addSubview(amount)
        addSubview(address)
        separators.forEach { addSubview($0) }
        addSubview(statusHeader)
        addSubview(status)
        addSubview(commentsHeader)
        addSubview(comments)
        addSubview(amountHeader)
        addSubview(amountDetails)
        addSubview(addressHeader)
        addSubview(fullAddress)

        header.constrainTopCorners(height: 48.0)
        timestamp.constrain([
            timestamp.leadingAnchor.constraint(equalTo: leadingAnchor, constant: C.padding[2]),
            timestamp.topAnchor.constraint(equalTo: header.bottomAnchor, constant: C.padding[3]),
            timestamp.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -C.padding[2]) ])
        amount.constrain([
            amount.leadingAnchor.constraint(equalTo: timestamp.leadingAnchor),
            amount.trailingAnchor.constraint(equalTo: timestamp.trailingAnchor),
            amount.topAnchor.constraint(equalTo: timestamp.bottomAnchor, constant: C.padding[1]) ])
        address.constrain([
            address.leadingAnchor.constraint(equalTo: amount.leadingAnchor),
            address.trailingAnchor.constraint(equalTo: amount.trailingAnchor),
            address.topAnchor.constraint(equalTo: amount.bottomAnchor) ])
        separators[0].constrain([
            separators[0].topAnchor.constraint(equalTo: address.bottomAnchor, constant: C.padding[2]),
            separators[0].leadingAnchor.constraint(equalTo: address.leadingAnchor),
            separators[0].trailingAnchor.constraint(equalTo: address.trailingAnchor),
            separators[0].heightAnchor.constraint(equalToConstant: 1.0)])
        statusHeader.constrain([
            statusHeader.topAnchor.constraint(equalTo: separators[0].bottomAnchor, constant: C.padding[2]),
            statusHeader.leadingAnchor.constraint(equalTo: separators[0].leadingAnchor),
            statusHeader.trailingAnchor.constraint(equalTo: separators[0].trailingAnchor) ])
        status.constrain([
            status.topAnchor.constraint(equalTo: statusHeader.bottomAnchor),
            status.leadingAnchor.constraint(equalTo: statusHeader.leadingAnchor),
            status.trailingAnchor.constraint(equalTo: statusHeader.trailingAnchor) ])
        separators[1].constrain([
            separators[1].topAnchor.constraint(equalTo: status.bottomAnchor, constant: C.padding[2]),
            separators[1].leadingAnchor.constraint(equalTo: status.leadingAnchor),
            separators[1].trailingAnchor.constraint(equalTo: status.trailingAnchor),
            separators[1].heightAnchor.constraint(equalToConstant: 1.0) ])
        commentsHeader.constrain([
            commentsHeader.topAnchor.constraint(equalTo: separators[1].bottomAnchor, constant: C.padding[2]),
            commentsHeader.leadingAnchor.constraint(equalTo: separators[1].leadingAnchor),
            commentsHeader.trailingAnchor.constraint(equalTo: separators[1].trailingAnchor) ])
        comments.constrain([
            comments.topAnchor.constraint(equalTo: commentsHeader.bottomAnchor),
            comments.leadingAnchor.constraint(equalTo: commentsHeader.leadingAnchor),
            comments.trailingAnchor.constraint(equalTo: commentsHeader.trailingAnchor) ])
        separators[2].constrain([
            separators[2].topAnchor.constraint(equalTo: comments.bottomAnchor, constant: C.padding[2]),
            separators[2].leadingAnchor.constraint(equalTo: comments.leadingAnchor),
            separators[2].trailingAnchor.constraint(equalTo: comments.trailingAnchor),
            separators[2].heightAnchor.constraint(equalToConstant: 1.0) ])
        amountHeader.constrain([
            amountHeader.topAnchor.constraint(equalTo: separators[2].bottomAnchor, constant: C.padding[2]),
            amountHeader.leadingAnchor.constraint(equalTo: separators[2].leadingAnchor),
            amountHeader.trailingAnchor.constraint(equalTo: separators[2].trailingAnchor) ])
        amountDetails.constrain([
            amountDetails.topAnchor.constraint(equalTo: amountHeader.bottomAnchor),
            amountDetails.leadingAnchor.constraint(equalTo: amountHeader.leadingAnchor),
            amountDetails.trailingAnchor.constraint(equalTo: amountHeader.trailingAnchor) ])
        separators[3].constrain([
            separators[3].topAnchor.constraint(equalTo: amountDetails.bottomAnchor, constant: C.padding[2]),
            separators[3].leadingAnchor.constraint(equalTo: amountDetails.leadingAnchor),
            separators[3].trailingAnchor.constraint(equalTo: amountDetails.trailingAnchor),
            separators[3].heightAnchor.constraint(equalToConstant: 1.0) ])
        addressHeader.constrain([
            addressHeader.topAnchor.constraint(equalTo: separators[3].bottomAnchor, constant: C.padding[2]),
            addressHeader.leadingAnchor.constraint(equalTo: separators[3].leadingAnchor),
            addressHeader.trailingAnchor.constraint(equalTo: separators[3].trailingAnchor) ])
        fullAddress.constrain([
            fullAddress.topAnchor.constraint(equalTo: addressHeader.bottomAnchor),
            fullAddress.leadingAnchor.constraint(equalTo: addressHeader.leadingAnchor),
            fullAddress.trailingAnchor.constraint(equalTo: addressHeader.trailingAnchor) ])
        separators[4].constrain([
            separators[4].topAnchor.constraint(equalTo: fullAddress.bottomAnchor, constant: C.padding[2]),
            separators[4].leadingAnchor.constraint(equalTo: fullAddress.leadingAnchor),
            separators[4].trailingAnchor.constraint(equalTo: fullAddress.trailingAnchor),
            separators[4].heightAnchor.constraint(equalToConstant: 1.0) ])

        statusHeader.text = S.TransactionDetails.statusHeader
        commentsHeader.text = S.TransactionDetails.commentsHeader
        amountHeader.text = S.TransactionDetails.amountHeader

        fullAddress.numberOfLines = 0
        fullAddress.lineBreakMode = .byCharWrapping

    }

    override func layoutSubviews() {
        let path = UIBezierPath(roundedRect: bounds, byRoundingCorners: [.topLeft, .topRight], cornerRadii: CGSize(width: 6.0, height: 6.0)).cgPath
        let maskLayer = CAShapeLayer()
        maskLayer.path = path
        layer.mask = maskLayer
    }

    private let header = ModalHeaderView(title: S.TransactionDetails.title, isFaqHidden: false, style: .dark)
    private let timestamp = UILabel(font: .customBold(size: 14.0), color: .grayTextTint)
    private let amount = UILabel.wrapping(font: .customBold(size: 26.0), color: .darkText)
    private let address = UILabel(font: .customBold(size: 14.0), color: .darkText)
    private let separators = (0...4).map { _ in UIView(color: .secondaryShadow) }
    private let statusHeader = UILabel(font: .customBold(size: 14.0), color: .grayTextTint)
    private let status = UILabel.wrapping(font: .customBody(size: 13.0), color: .darkText)
    private let commentsHeader = UILabel(font: .customBold(size: 14.0), color: .grayTextTint)
    private let comments = UILabel(font: .customBody(size: 13.0), color: .darkText)
    private let amountHeader = UILabel(font: .customBold(size: 14.0), color: .grayTextTint)
    private let amountDetails = UILabel(font: .customBody(size: 13.0), color: .darkText)
    private let addressHeader = UILabel(font: .customBold(size: 14.0), color: .grayTextTint)
    private let fullAddress = UILabel(font: .customBody(size: 13.0), color: .darkText)

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
