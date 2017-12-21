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
    // TODO: animated status indicator
    
    // MARK: - Init
    
    override func addSubviews() {
        super.addSubviews()
        container.addSubview(statusLabel)
    }
    
    override func addConstraints() {
        super.addConstraints()
        
        statusLabel.setContentCompressionResistancePriority(UILayoutPriority.required, for: .horizontal)
        statusLabel.constrain([
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: statusLabel.leadingAnchor, constant: -C.padding[1]),
            statusLabel.constraint(.trailing, toView: container, constant: -C.padding[2]),
            statusLabel.constraint(.top, toView: container, constant: C.padding[2])
            ])
    }
    
    override func setupStyle() {
        super.setupStyle()
        statusLabel.textColor = .darkText
    }
    
    // MARK: -
    
    func set(status: TxConfirmationStatus) {
        switch status {
        case .complete:
            statusLabel.text = "complete"
        case .confirmedFirstBlock:
            statusLabel.text = "firstBlock"
        case .networkReceived:
            statusLabel.text = "unconfirmed"
        }
    }

}
