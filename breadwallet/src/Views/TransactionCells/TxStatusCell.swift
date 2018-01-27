//
//  TxStatusCell.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2017-12-20.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

class TxStatusCell: TxDetailRowCell, Subscriber {

    // MARK: - Views
    
    private let statusLabel = UILabel(font: UIFont.customMedium(size: 13.0))
    private let statusIndicator = TxStatusIndicator()
    
    // MARK: - Init
    
    override func addSubviews() {
        super.addSubviews()
        container.addSubview(statusLabel)
        container.addSubview(statusIndicator)
    }
    
    override func addConstraints() {
        super.addConstraints()
        
        statusLabel.setContentCompressionResistancePriority(UILayoutPriority.required, for: .horizontal)
        statusLabel.constrain([
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: statusLabel.leadingAnchor, constant: -C.padding[1]),
            statusLabel.constraint(.trailing, toView: container),
            statusLabel.constraint(.top, toView: container),
            statusLabel.constraint(.bottom, toView: container)
            ])
        
        statusIndicator.constrain([
            statusIndicator.constraint(toLeading: statusLabel, constant: -C.padding[1]),
            statusIndicator.constraint(.centerY, toView: container),
            statusIndicator.widthAnchor.constraint(equalToConstant: statusIndicator.width),
            statusIndicator.heightAnchor.constraint(equalToConstant: statusIndicator.size)
            ])
    }
    
    override func setupStyle() {
        super.setupStyle()
        statusLabel.textColor = .darkText
    }
    
    // MARK: -
    
    func set(txInfo: TxDetailViewModel) {
        Store.lazySubscribe(self,
                            selector: { $0[txInfo.currency].transactions != $1[txInfo.currency].transactions },
                            callback: { [weak self] state in
                                guard let `self` = self,
                                    let updatedTx = state[txInfo.currency].transactions.filter({ $0.hash == txInfo.transactionHash }).first else { return }
                                DispatchQueue.main.async {
                                    let updatedInfo = TxDetailViewModel(tx: updatedTx)
                                    self.update(status: updatedInfo.status)
                                }
        })
        
        update(status: txInfo.status)
    }
    
    private func update(status: TransactionStatus) {
        statusIndicator.status = status
        switch status {
        case .pending:
            statusLabel.text = S.Transaction.pending
        case .confirmed:
            statusLabel.text = S.Transaction.confirming
        case .complete:
            statusLabel.text = S.Transaction.complete
        case .invalid:
            statusLabel.text = S.Transaction.invalid
        }
    }
    
    deinit {
        Store.unsubscribe(self)
    }
}
