//
//  TxViewModel.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2018-01-11.
//  Copyright © 2018-2019 Breadwinner AG. All rights reserved.
//

import Foundation
import BRCrypto

/// Representation of a transaction
protocol TxViewModel {
    var tx: Transaction { get }
    var currency: Currency { get }
    var blockHeight: String { get }
    var longTimestamp: String { get }
    var status: TransactionStatus { get }
    var direction: TransferDirection { get }
    var displayAddress: String { get }
    var comment: String? { get }
    var tokenTransferCode: String? { get }
}

// Default and passthru values
extension TxViewModel {

    var currency: Currency { return tx.currency }
    var status: TransactionStatus { return tx.status }
    var direction: TransferDirection { return tx.direction }
    var comment: String? { return tx.comment }
    
    // BTC does not have "from" address, only "sent to" or "received at"
    var displayAddress: String {
        if tx.currency.isEthereumCompatible {
            if direction == .sent {
                return tx.toAddress
            } else {
                return tx.fromAddress
            }
        } else {
            return tx.toAddress
        }
    }
    
    var blockHeight: String {
        return tx.blockNumber?.description ?? S.TransactionDetails.notConfirmedBlockHeightLabel
    }
    
    var confirmations: String {
        return "\(tx.confirmations)"
    }
    
    var longTimestamp: String {
        guard tx.timestamp > 0 else { return tx.isValid ? S.Transaction.justNow : "" }
        let date = Date(timeIntervalSince1970: tx.timestamp)
        return DateFormatter.longDateFormatter.string(from: date)
    }
    
    var shortTimestamp: String {
        guard tx.timestamp > 0 else { return tx.isValid ? S.Transaction.justNow : "" }
        let date = Date(timeIntervalSince1970: tx.timestamp)
        return DateFormatter.shortDateFormatter.string(from: date)
    }
    
    var tokenTransferCode: String? {
        guard let code = tx.metaData?.tokenTransfer, !code.isEmpty else { return nil }
        return code
    }
}

// MARK: - Formatting

extension DateFormatter {
    static let longDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.setLocalizedDateFormatFromTemplate("MMMM d, yyy h:mm a")
        return df
    }()
    
    static let shortDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.setLocalizedDateFormatFromTemplate("MMM d")
        return df
    }()

    static let mediumDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.setLocalizedDateFormatFromTemplate("MMM d, YYYY")
        return df
    }()
}

private extension String {
    var smallCondensed: String {
        let start = String(self[..<index(startIndex, offsetBy: 5)])
        let end = String(self[index(endIndex, offsetBy: -5)...])
        return start + "..." + end
    }
    
    var largeCondensed: String {
        let start = String(self[..<index(startIndex, offsetBy: 10)])
        let end = String(self[index(endIndex, offsetBy: -10)...])
        return start + "..." + end
    }
}
