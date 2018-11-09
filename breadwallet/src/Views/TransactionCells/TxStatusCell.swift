//
//  TxStatusCell.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2017-12-20.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

class TxStatusCell: UITableViewCell, Subscriber {

    // MARK: - Views
    
    private let container = UIView()
    private lazy var statusLabel: UILabel = {
        let label = UILabel(font: UIFont.customBody(size: 14.0))
        label.textColor = .darkGray
        label.textAlignment = .center
        return label
    }()
    private let statusIndicator = TxStatusIndicator(width: 238.0)
    
    // MARK: - Init
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }
    
    private func setupViews() {
        addSubviews()
        addConstraints()
    }
    
    private func addSubviews() {
        contentView.addSubview(container)
        container.addSubview(statusLabel)
        container.addSubview(statusIndicator)
    }
    
    private func addConstraints() {

        container.constrain(toSuperviewEdges: UIEdgeInsets(top: C.padding[1],
                                                           left: C.padding[1],
                                                           bottom: -C.padding[2],
                                                           right: -C.padding[1]))
        
        statusIndicator.constrain([
            statusIndicator.topAnchor.constraint(equalTo: container.topAnchor),
            statusIndicator.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            statusIndicator.widthAnchor.constraint(equalToConstant: statusIndicator.width),
            statusIndicator.heightAnchor.constraint(equalToConstant: statusIndicator.height)
            ])
        
        statusLabel.constrain([
            statusLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            statusLabel.topAnchor.constraint(equalTo: statusIndicator.bottomAnchor),
            statusLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor)
            ])
    }
    
    // MARK: -
    
    func set(txInfo: TxDetailViewModel) {
        Store.lazySubscribe(self,
                            selector: {
                                guard let oldTransactions = $0[txInfo.currency]?.transactions else { return false}
                                guard let newTransactions = $1[txInfo.currency]?.transactions else { return false}
                                return oldTransactions != newTransactions },
                            callback: { [weak self] state in
                                guard let `self` = self,
                                    let updatedTx = state[txInfo.currency]?.transactions.filter({ $0.hash == txInfo.transactionHash }).first else { return }
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
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
