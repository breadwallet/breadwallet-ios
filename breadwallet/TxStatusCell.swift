//
//  TxStatusCell.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2017-12-20.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

class TxStatusCell: TxDetailRowCell {

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
    
    func set(status: TxConfirmationStatus) {
        statusIndicator.status = status
        switch status {
        case .networkReceived:
            statusLabel.text = S.Transaction.pending
        case .confirmedFirstBlock:
            statusLabel.text = S.Transaction.confirming
        case .complete:
            statusLabel.text = S.Transaction.complete
        }
    }

}
