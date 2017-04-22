//
//  TransactionDetailCollectionViewCell.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-02-09.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

class TransactionDetailCollectionViewCell : UICollectionViewCell {

    //MARK: - Public
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    func set(transaction: Transaction, currency: Currency, rate: Rate) {
        timestamp.text = transaction.longTimestamp
        amount.text = "\(transaction.direction.rawValue) \(transaction.amountDescription(currency: currency, rate: rate))"
        address.text = "\(transaction.direction.preposition) an address"
        status.text = transaction.longStatus
        comment.text = transaction.comment
        amountDetails.text = transaction.amountDetails(currency: currency, rate: rate)
        addressHeader.text = "To" //Should this be from sometimes?
        fullAddress.text = transaction.toAddress ?? ""
        self.transaction = transaction
        self.rate = rate
    }

    var closeCallback: (() -> Void)? {
        didSet {
            header.closeCallback = closeCallback
        }
    }

    var kvStore: BRReplicatedKVStore?
    var transaction: Transaction?
    var rate: Rate?

    //MARK: - Private
    private func setup() {
        backgroundColor = .white

        let scrollView = UIScrollView()
        contentView.addSubview(scrollView)
        contentView.addSubview(header)
        header.constrainTopCorners(height: 48.0)
        scrollView.constrain(toSuperviewEdges: UIEdgeInsets(top: 48.0, left: 0, bottom: 0, right: 0))

        let scrollViewContent = UIView()
        scrollView.addSubview(scrollViewContent)

        scrollViewContent.constrain([
            scrollViewContent.widthAnchor.constraint(equalTo: scrollView.widthAnchor) ])

        scrollViewContent.addSubview(timestamp)
        scrollViewContent.addSubview(amount)
        scrollViewContent.addSubview(address)
        separators.forEach { scrollViewContent.addSubview($0) }
        scrollViewContent.addSubview(statusHeader)
        scrollViewContent.addSubview(status)
        scrollViewContent.addSubview(commentsHeader)
        scrollViewContent.addSubview(comment)
        scrollViewContent.addSubview(amountHeader)
        scrollViewContent.addSubview(amountDetails)
        scrollViewContent.addSubview(addressHeader)
        scrollViewContent.addSubview(fullAddress)

        timestamp.constrain([
            timestamp.leadingAnchor.constraint(equalTo: scrollViewContent.leadingAnchor, constant: C.padding[2]),
            timestamp.topAnchor.constraint(equalTo: scrollViewContent.topAnchor, constant: C.padding[3]),
            timestamp.trailingAnchor.constraint(equalTo: scrollViewContent.trailingAnchor, constant: -C.padding[2]) ])
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
        comment.constrain([
            comment.topAnchor.constraint(equalTo: commentsHeader.bottomAnchor),
            comment.leadingAnchor.constraint(equalTo: commentsHeader.leadingAnchor),
            comment.trailingAnchor.constraint(equalTo: commentsHeader.trailingAnchor),
            comment.heightAnchor.constraint(greaterThanOrEqualToConstant: 44.0) ])
        separators[2].constrain([
            separators[2].topAnchor.constraint(equalTo: comment.bottomAnchor, constant: C.padding[2]),
            separators[2].leadingAnchor.constraint(equalTo: comment.leadingAnchor),
            separators[2].trailingAnchor.constraint(equalTo: comment.trailingAnchor),
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
            separators[4].heightAnchor.constraint(equalToConstant: 1.0),
            separators[4].bottomAnchor.constraint(equalTo: scrollViewContent.bottomAnchor, constant: -C.padding[2]) ])

        statusHeader.text = S.TransactionDetails.statusHeader
        commentsHeader.text = S.TransactionDetails.commentsHeader
        amountHeader.text = S.TransactionDetails.amountHeader

        fullAddress.numberOfLines = 0
        fullAddress.lineBreakMode = .byCharWrapping

        comment.font = .customBody(size: 13.0)
        comment.textColor = .darkText
        comment.contentVerticalAlignment = .top
        comment.returnKeyType = .done
        comment.delegate = self
    }

    override func layoutSubviews() {
        let path = UIBezierPath(roundedRect: bounds, byRoundingCorners: [.topLeft, .topRight], cornerRadii: CGSize(width: 6.0, height: 6.0)).cgPath
        let maskLayer = CAShapeLayer()
        maskLayer.path = path
        layer.mask = maskLayer
    }

    fileprivate func saveComment(comment: String) {
        guard let kvStore = self.kvStore else { return }
        if let metaData = transaction?.metaData {
            metaData.comment = comment
            do {
                let _ = try kvStore.set(metaData)
            } catch let error {
                print("could not update metadata: \(error)")
            }
        } else {
            guard let rate = self.rate else { return }
            guard let transaction = self.transaction else { return }
            let newMetaData = BRTxMetadataObject(transaction: transaction.rawTransaction, exchangeRate: rate.rate, exchangeRateCurrency: rate.code, feeRate: 0.0, deviceId: UserDefaults.standard.deviceID)
            newMetaData.comment = comment
            do {
                let _ = try kvStore.set(newMetaData)
            } catch let error {
                print("could not update metadata: \(error)")
            }
        }
        NotificationCenter.default.post(name: .WalletTxStatusUpdateNotification, object: nil)
    }

    //TODO - this will need to get the real store somehow
    private let header = ModalHeaderView(title: S.TransactionDetails.title, style: .dark, store: Store(), faqArticleId: ArticleIds.transactionDetails)
    private let timestamp = UILabel(font: .customBold(size: 14.0), color: .grayTextTint)
    private let amount = UILabel(font: .customBold(size: 26.0), color: .darkText)
    private let address = UILabel(font: .customBold(size: 14.0), color: .darkText)
    private let separators = (0...4).map { _ in UIView(color: .secondaryShadow) }
    private let statusHeader = UILabel(font: .customBold(size: 14.0), color: .grayTextTint)
    private let status = UILabel.wrapping(font: .customBody(size: 13.0), color: .darkText)
    private let commentsHeader = UILabel(font: .customBold(size: 14.0), color: .grayTextTint)
    private let comment = UITextField()
    private let amountHeader = UILabel(font: .customBold(size: 14.0), color: .grayTextTint)
    private let amountDetails = UILabel.wrapping(font: .customBody(size: 13.0), color: .darkText)
    private let addressHeader = UILabel(font: .customBold(size: 14.0), color: .grayTextTint)
    private let fullAddress = UILabel(font: .customBody(size: 13.0), color: .darkText)

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension TransactionDetailCollectionViewCell : UITextFieldDelegate {

    func textFieldDidEndEditing(_ textField: UITextField) {
        guard let text = textField.text else { return }
        saveComment(comment: text)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

}
