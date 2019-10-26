//
//  TxListViewModel.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2018-01-13.
//  Copyright © 2018-2019 Breadwinner AG. All rights reserved.
//

import UIKit

/// View model of a transaction in list view
struct TxListViewModel: TxViewModel {
    
    // MARK: - Properties
    
    let tx: Transaction
    
    var shortDescription: String {
        let isComplete = tx.status == .complete
        
        if let comment = comment, !comment.isEmpty, isComplete {
            return comment
        } else if let tokenCode = tokenTransferCode {
            return String(format: S.Transaction.tokenTransfer, tokenCode.uppercased())
        } else {
            var address = tx.toAddress
            var format: String
            switch tx.direction {
            case .sent, .recovered:
                format = isComplete ? S.Transaction.sentTo : S.Transaction.sendingTo
            case .received:
                //TODO:CRYPTO via/from
                if tx.currency.isEthereumCompatible {
                    format = isComplete ? S.Transaction.receivedFrom : S.Transaction.receivingFrom
                    address = tx.fromAddress
                } else {
                    format = isComplete ? S.Transaction.receivedVia : S.Transaction.receivingVia
                }
            }
            return String(format: format, address)
        }
    }

    func amount(showFiatAmounts: Bool, rate: Rate) -> NSAttributedString {
        var amount = tx.amount

        if tokenTransferCode != nil {
            // this is the originating tx of a token transfer, so the amount is 0 but we want to show the fee
            amount = tx.fee
        }

        let text = Amount(amount: amount,
                          rate: showFiatAmounts ? rate : nil,
                          negative: (tx.direction == .sent)).description
        let color: UIColor = (tx.direction == .received) ? .receivedGreen : .darkGray
        
        return NSMutableAttributedString(string: text,
                                         attributes: [.foregroundColor: color])
    }
}
