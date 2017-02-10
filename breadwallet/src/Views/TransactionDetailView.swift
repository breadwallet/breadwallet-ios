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
    init() {
        super.init(frame: .zero)
        setup()
    }

    var transaction: Transaction? {
        didSet {
            guard let transaction = transaction else { return }
            timestamp.text = transaction.longTimestamp
            amount.text = "\(transaction.direction.rawValue) \(transaction.amount.bits)"
            address.text = "\(transaction.direction.preposition) an address"
        }
    }

    //MARK: - Private
    private func setup() {
        backgroundColor = .white
        addSubview(header)
        addSubview(timestamp)
        addSubview(amount)
        addSubview(address)
        separators.forEach { addSubview($0) }

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
    }

    private let header = ModalHeaderView(title: S.TransactionDetails.title, isFaqHidden: false)
    private let timestamp = UILabel(font: .customBold(size: 14.0), color: .grayTextTint)
    private let amount = UILabel(font: .customBold(size: 26.0), color: .darkText)
    private let address = UILabel(font: .customBold(size: 14.0), color: .darkText)
    private let separators = (0...4).map { _ in UIView(color: .secondaryShadow) }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
