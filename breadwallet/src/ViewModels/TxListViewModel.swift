//
//  TxListViewModel.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2018-01-13.
//  Copyright © 2018 breadwallet LLC. All rights reserved.
//

import UIKit

/// View model of a transaction in list view
struct TxListViewModel: TxViewModel {
    
    // MARK: - Properties
    
    let tx: Transaction
    
    var shortDescription: String {
        let isComplete = tx.status == .complete
        
        if let comment = comment, comment.count > 0, isComplete {
            return comment
        } else {
            var format: String
            switch tx.direction {
            case .sent, .moved:
                format = isComplete ? S.Transaction.sentTo : S.Transaction.sendingTo
            case .received:
                format = isComplete ? S.Transaction.receivedVia : S.Transaction.receivingVia
            }
            var address = tx.toAddress
            if currency.matches(Currencies.bch) {
                address = address.replacingOccurrences(of: "\(Currencies.bch.urlScheme!):", with: "")
            }
            return String(format: format, address)
        }
    }

    func amount(isBtcSwapped: Bool, rate: Rate) -> NSAttributedString {
        guard let tx = tx as? BtcTransaction else { return NSAttributedString(string: "") }
        let text = DisplayAmount(amount: Satoshis(rawValue: tx.amount),
                                 selectedRate: isBtcSwapped ? rate : nil,
                                 minimumFractionDigits: nil,
                                 currency: tx.currency,
                                 negative: (tx.direction == .sent)).description
        let color: UIColor = (tx.direction == .received) ? .receivedGreen : .darkGray
        
        return NSMutableAttributedString(string: text,
                                         attributes: [.foregroundColor: color])
    }
}
