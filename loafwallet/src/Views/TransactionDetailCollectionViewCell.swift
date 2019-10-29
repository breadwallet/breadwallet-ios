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
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: .UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: .UIKeyboardWillHide, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func set(transaction: Transaction, isLtcSwapped: Bool, rate: Rate, rates: [Rate], maxDigits: Int) {
        
        guard let address = self.address,
            let amount = self.amount,
            let amountDetails = self.amountDetails,
            let status = self.status,
            let addressHeader = self.addressHeader,
            let timestamp = self.timestamp,
            let availability = self.availability,
            let blockHeight = self.blockHeight else {
                NSLog("ERROR: a UILabel was not initialized")
                return
        }
        
        timestamp.text = transaction.longTimestamp
        amount.text = String(format: transaction.direction.amountFormat, "\(transaction.amountDescription(isLtcSwapped: isLtcSwapped, rate: rate, maxDigits: maxDigits))")
        address.text = transaction.detailsAddressText
        status.text = transaction.status
        comment.text = transaction.comment
        amountDetails.text = transaction.amountDetails(isLtcSwapped: isLtcSwapped, rate: rate, rates: rates, maxDigits: maxDigits)
        addressHeader.text = transaction.direction.addressHeader.capitalized
        fullAddress.setTitle(transaction.toAddress ?? "", for: .normal)
        txHash.setTitle(transaction.hash, for: .normal)
        availability.isHidden = !transaction.shouldDisplayAvailableToSpend
        blockHeight.text = transaction.blockHeight
        self.transaction = transaction
        self.rate = rate
    }

    var closeCallback: (() -> Void)? {
        didSet {
            header.closeCallback = closeCallback
        }
    }

    var didBeginEditing: (() -> Void)?
    var didEndEditing: (() -> Void)?
    var modalTransitioningDelegate: ModalTransitionDelegate?

    var kvStore: BRReplicatedKVStore?
    var transaction: Transaction?
    var rate: Rate?
    var store: Store? {
        didSet {
            if oldValue == nil {
                guard let store = store else { return }
                header.faqInfo = (store, ArticleIds.transactionDetails)
            }
        }
    }

    //MARK: - Private
    private let header = ModalHeaderView(title: S.TransactionDetails.title, style: .dark)
    var timestamp: UILabel?
    var amount: UILabel?
    var address: UILabel?
    var separators = (0...4).map { _ in UIView(color: .secondaryShadow) }
    var statusHeader: UILabel?
    var status: UILabel?
    var commentsHeader: UILabel?
    var amountHeader: UILabel?
    var amountDetails: UILabel?
    var addressHeader: UILabel?
    var comment = UITextView()
    var fullAddress = UIButton(type: .system)
    private let headerHeight: CGFloat = 70
    private let scrollViewContent = UIView()
    private let scrollView = UIScrollView()
    private var moreButton = UIButton(type: .system)
    private let moreContentView = UIView()
    private var txHash = UIButton(type: .system)
    var txHashHeader: UILabel? // = UILabel(font: .customBold(size: 14.0), color: .grayTextTint)
    var availability: UILabel? //= UILabel(font: .customBold(size: 13.0), color: .txListGreen)
    var blockHeight: UILabel? // = UILabel(font: .customBody(size: 13.0), color: .darkText)
    private var scrollViewHeight: NSLayoutConstraint?

    private func setup() {
        
        self.backgroundColor = .white
        self.timestamp = UILabel(font: .customBold(size: 14.0), color: .grayTextTint)
        self.amount = UILabel(font: .customBold(size: 26.0), color: .darkText)
        self.address = UILabel(font: .customBold(size: 14.0), color: .darkText)
        self.statusHeader = UILabel(font: .customBold(size: 14.0), color: .darkText)
        self.status = UILabel.wrapping(font: .customBody(size: 13.0), color: .darkText)
        self.commentsHeader = UILabel(font: .customBold(size: 14.0), color: .grayTextTint)
        self.amountHeader = UILabel(font: .customBold(size: 14.0), color: .grayTextTint)
        self.amountDetails = UILabel(font: .customBold(size: 14.0), color: .grayTextTint)
        self.addressHeader = UILabel(font: .customBold(size: 14.0), color: .grayTextTint)
        self.txHashHeader = UILabel(font: .customBold(size: 14.0), color: .grayTextTint)
        self.availability = UILabel(font: .customBold(size: 13.0), color: .txListGreen)
        self.blockHeight = UILabel(font: .customBold(size: 14.0), color: .darkText)
        self.comment.textColor = .darkText

        if #available(iOS 11.0, *),
          let textColor = UIColor(named: "labelTextColor"),
            let headerTextColor = UIColor(named: "headerTextColor"),
            let darkModeBackgroundColor = UIColor(named: "lfBackgroundColor") {
            separators = (0...4).map { _ in UIView(color: headerTextColor) }
          self.backgroundColor = darkModeBackgroundColor
          self.timestamp = UILabel(font: .customBold(size: 14.0), color: headerTextColor)
          self.amount = UILabel(font: .customBold(size: 26.0), color: textColor)
          self.address = UILabel(font: .customBold(size: 14.0), color: textColor)
          self.statusHeader = UILabel(font: .customBold(size: 14.0), color: textColor)
          self.status = UILabel.wrapping(font: .customBody(size: 13.0), color: textColor)
          self.commentsHeader = UILabel(font: .customBold(size: 14.0), color: headerTextColor)
          self.amountHeader = UILabel(font: .customBold(size: 14.0), color: headerTextColor)
          self.amountDetails = UILabel.wrapping(font: .customBody(size: 13.0), color: headerTextColor)
          self.addressHeader = UILabel(font: .customBold(size: 14.0), color: textColor)
          self.txHashHeader = UILabel(font: .customBold(size: 14.0), color: headerTextColor)
          self.blockHeight = UILabel(font: .customBody(size: 13.0), color: textColor)
          self.txHash.setTitleColor(textColor, for: .normal)
          self.moreButton.setTitleColor(textColor, for: .normal)
          self.fullAddress.setTitleColor(textColor, for: .normal)
          self.comment.textColor = textColor
          self.comment.backgroundColor = darkModeBackgroundColor
            
        }
        addSubviews()
        addConstraints()
        setData()
    }

    private func addSubviews() {
        
        
        guard let address = self.address,
            let amount = self.amount,
            let amountDetails = self.amountDetails,
            let amountHeader = self.amountHeader,
            let status = self.status,
            let statusHeader = self.statusHeader,
            let commentsHeader = self.commentsHeader,
            let addressHeader = self.addressHeader,
            let availability = self.availability,
            let timestamp = self.timestamp else {
                NSLog("ERROR: a UILabel was not initialized")
                return
        }
        
        contentView.addSubview(scrollView)
        contentView.addSubview(header)
        scrollView.addSubview(scrollViewContent)
        scrollViewContent.addSubview(timestamp)
        scrollViewContent.addSubview(amount)
        scrollViewContent.addSubview(address)
        separators.forEach { scrollViewContent.addSubview($0) }
        scrollViewContent.addSubview(statusHeader)
        scrollViewContent.addSubview(status)
        scrollViewContent.addSubview(availability)
        scrollViewContent.addSubview(commentsHeader)
        scrollViewContent.addSubview(comment)
        scrollViewContent.addSubview(amountHeader)
        scrollViewContent.addSubview(amountDetails)
        scrollViewContent.addSubview(addressHeader)
        scrollViewContent.addSubview(fullAddress)
        scrollViewContent.addSubview(moreContentView)
        moreContentView.addSubview(moreButton)
    }

    private func addConstraints() {
        
        guard let address = self.address,
            let amount = self.amount,
            let amountDetails = self.amountDetails,
            let amountHeader = self.amountHeader,
            let status = self.status,
            let statusHeader = self.statusHeader,
            let commentsHeader = self.commentsHeader,
            let addressHeader = self.addressHeader,
            let timestamp = self.timestamp,
            let availability = self.availability,
            let blockHeight = self.blockHeight else {
                NSLog("ERROR: a UILabel was not initialized")
                return
        }
        
        header.constrainTopCorners(height: headerHeight)
        scrollViewHeight = scrollView.heightAnchor.constraint(equalTo: contentView.heightAnchor, constant: -headerHeight)
        scrollView.constrain([
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: headerHeight),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollViewHeight ])
        scrollViewContent.constrain([
            scrollViewContent.topAnchor.constraint(equalTo: scrollView.topAnchor),
            scrollViewContent.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            scrollViewContent.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            scrollViewContent.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            scrollViewContent.widthAnchor.constraint(equalTo: scrollView.widthAnchor) ])
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
        availability.constrain([
            availability.topAnchor.constraint(equalTo: status.bottomAnchor),
            availability.leadingAnchor.constraint(equalTo: status.leadingAnchor)])
        separators[1].constrain([
            separators[1].topAnchor.constraint(equalTo: availability.bottomAnchor, constant: C.padding[2]),
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
            comment.trailingAnchor.constraint(equalTo: commentsHeader.trailingAnchor) ])
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
            fullAddress.trailingAnchor.constraint(lessThanOrEqualTo: addressHeader.trailingAnchor) ])
        separators[4].constrain([
            separators[4].topAnchor.constraint(equalTo: fullAddress.bottomAnchor, constant: C.padding[2]),
            separators[4].leadingAnchor.constraint(equalTo: fullAddress.leadingAnchor),
            separators[4].trailingAnchor.constraint(equalTo: fullAddress.trailingAnchor),
            separators[4].heightAnchor.constraint(equalToConstant: 1.0) ])
        moreContentView.constrain([
            moreContentView.leadingAnchor.constraint(equalTo: separators[4].leadingAnchor),
            moreContentView.topAnchor.constraint(equalTo: separators[4].bottomAnchor, constant: C.padding[2]),
            moreContentView.trailingAnchor.constraint(equalTo: separators[4].trailingAnchor),
            moreContentView.bottomAnchor.constraint(equalTo: scrollViewContent.bottomAnchor, constant: -C.padding[2]) ])
        moreButton.constrain([
            moreButton.leadingAnchor.constraint(equalTo: moreContentView.leadingAnchor),
            moreButton.topAnchor.constraint(equalTo: moreContentView.topAnchor),
            moreButton.bottomAnchor.constraint(equalTo: moreContentView.bottomAnchor) ])
    }

    private func setData() {
        guard let amount = self.amount,
            let amountHeader = self.amountHeader,
            let statusHeader = self.statusHeader,
            let commentsHeader = self.commentsHeader,
            let availability = self.availability else {
                NSLog("ERROR: a UILabel was not initialized")
                return
        }
        statusHeader.text = S.TransactionDetails.statusHeader
        commentsHeader.text = S.TransactionDetails.commentsHeader
        amountHeader.text = S.TransactionDetails.amountHeader
        availability.text = S.Transaction.available

        comment.font = .customBody(size: 13.0)
        comment.isScrollEnabled = false
        comment.returnKeyType = .done
        comment.delegate = self

        moreButton.setTitle(S.TransactionDetails.more, for: .normal)
//        moreButton.tintColor = .grayTextTint
        moreButton.titleLabel?.font = .customBold(size: 14.0)

        moreButton.tap = { [weak self] in
            self?.addMoreView()
        }

        amount.minimumScaleFactor = 0.5
        amount.adjustsFontSizeToFitWidth = true

        fullAddress.titleLabel?.font = .customBody(size: 13.0)
        fullAddress.titleLabel?.numberOfLines = 0
        fullAddress.titleLabel?.lineBreakMode = .byCharWrapping
        fullAddress.tap = strongify(self) { myself in
            myself.fullAddress.tempDisable()
            myself.store?.trigger(name: .lightWeightAlert(S.Receive.copied))
            UIPasteboard.general.string = myself.fullAddress.titleLabel?.text
        }
        fullAddress.contentHorizontalAlignment = .left

        txHash.titleLabel?.font = .customBody(size: 13.0)
        txHash.titleLabel?.numberOfLines = 0
        txHash.titleLabel?.lineBreakMode = .byCharWrapping
//        txHash.tintColor = .darkText
        txHash.contentHorizontalAlignment = .left
        txHash.tap = strongify(self) { myself in
            myself.txHash.tempDisable()
            myself.store?.trigger(name: .lightWeightAlert(S.Receive.copied))
            UIPasteboard.general.string = myself.txHash.titleLabel?.text
        }
    }

    private func addMoreView() {
        
//
        guard let blockHeight = self.blockHeight,
            let txHashHeader = self.txHashHeader else {
                NSLog("ERROR: a UILabel was not initialized")
                return
        }
//
//
//        var modeTextColor = UIColor
//        if #available(iOS 11.0, *) {
//
//            txHashHeader.textColor
//        }
////        let textColor = UIColor(named: "labelTextColor"),
////          let headerTextColor = UIColor(named: "headerTextColor"),
////          let darkModeBackgroundColor = UIColor(named: "lfBackgroundColor") {
////          separators = (0...4).map { _ in UIView(color: headerTextColor) }
////        self.backgroundColor = darkModeBackgroundColor
////        self.timestamp = UILabel(font: .customBold(size: 14.0), color: headerTextColor)
////        self.amount = UILabel(font: .customBold(size: 26.0), color: textColor)
////        self.
//
        moreButton.removeFromSuperview()
        let newSeparator = UIView(color: .secondaryShadow)
        moreContentView.addSubview(newSeparator)
        moreContentView.addSubview(txHashHeader)
        moreContentView.addSubview(txHash)
        txHashHeader.text = S.TransactionDetails.txHashHeader
        txHashHeader.constrain([
            txHashHeader.leadingAnchor.constraint(equalTo: moreContentView.leadingAnchor),
            txHashHeader.topAnchor.constraint(equalTo: moreContentView.topAnchor) ])
        txHash.constrain([
            txHash.leadingAnchor.constraint(equalTo: txHashHeader.leadingAnchor),
            txHash.topAnchor.constraint(equalTo: txHashHeader.bottomAnchor, constant: 2.0),
            txHash.trailingAnchor.constraint(lessThanOrEqualTo: moreContentView.trailingAnchor) ])

        let blockHeightHeader = UILabel(font: txHashHeader.font, color: txHashHeader.textColor)
        blockHeightHeader.text = S.TransactionDetails.blockHeightLabel
        moreContentView.addSubview(blockHeightHeader)
        moreContentView.addSubview(blockHeight)
        blockHeightHeader.constrain([
            blockHeightHeader.leadingAnchor.constraint(equalTo: txHashHeader.leadingAnchor),
            blockHeightHeader.topAnchor.constraint(equalTo: txHash.bottomAnchor, constant: C.padding[1]) ])
        blockHeight.constrain([
            blockHeight.leadingAnchor.constraint(equalTo: blockHeightHeader.leadingAnchor),
            blockHeight.topAnchor.constraint(equalTo: blockHeightHeader.bottomAnchor) ])

        newSeparator.constrain([
            newSeparator.leadingAnchor.constraint(equalTo: blockHeight.leadingAnchor),
            newSeparator.topAnchor.constraint(equalTo: blockHeight.bottomAnchor, constant: C.padding[2]),
            newSeparator.trailingAnchor.constraint(equalTo: moreContentView.trailingAnchor),
            newSeparator.heightAnchor.constraint(equalToConstant: 1.0),
            newSeparator.bottomAnchor.constraint(equalTo: moreContentView.bottomAnchor) ])

        //Scroll to expaned more view
        scrollView.layoutIfNeeded()
        if scrollView.contentSize.height > scrollView.bounds.height {
            let point = CGPoint(x: 0, y: scrollView.contentSize.height - scrollView.bounds.height)
            self.scrollView.setContentOffset(point, animated: true)
        }
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
            let newMetaData = TxMetaData(transaction: transaction.rawTransaction, exchangeRate: rate.rate, exchangeRateCurrency: rate.code, feeRate: 0.0, deviceId: UserDefaults.standard.deviceID)
            newMetaData.comment = comment
            do {
                let _ = try kvStore.set(newMetaData)
            } catch let error {
                print("could not update metadata: \(error)")
            }
        }
        if let tx = transaction {
            store?.trigger(name: .txMemoUpdated(tx.hash))
        }
    }

    //MARK: - Keyboard Notifications
    @objc private func keyboardWillShow(notification: Notification) {
        modalTransitioningDelegate?.shouldDismissInteractively = false
        respondToKeyboardAnimation(notification: notification)
    }

    @objc private func keyboardWillHide(notification: Notification) {
        modalTransitioningDelegate?.shouldDismissInteractively = true
        respondToKeyboardAnimation(notification: notification)
    }

    private func respondToKeyboardAnimation(notification: Notification) {
        guard let info = KeyboardNotificationInfo(notification.userInfo) else { return }
        guard let height = scrollViewHeight else { return }
        height.constant = height.constant + info.deltaY
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension TransactionDetailCollectionViewCell : UITextViewDelegate {

    func textViewDidBeginEditing(_ textView: UITextView) {
        didBeginEditing?()
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        didEndEditing?()
        guard let text = textView.text else { return }
        saveComment(comment: text)
    }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        guard text.rangeOfCharacter(from: CharacterSet.newlines) == nil else {
            textView.resignFirstResponder()
            return false
        }

        let count = (textView.text ?? "").utf8.count + text.utf8.count
        if count > C.maxMemoLength {
            return false
        } else {
            return true
        }
    }
}
