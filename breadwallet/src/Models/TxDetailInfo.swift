//
//  TxDetailInfo.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-12-20.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation

enum TxConfirmationStatus: Int {
    case networkReceived
    case confirmedFirstBlock
    case complete
}

struct TxDetailInfo {
    let amount: String
    let fiatAmount: String
    let status: TxConfirmationStatus
    let memo: String?
    let timestamp: String
    let address: String
    let startingBalance: String
    let endingBalance: String
    let exchangeRate: String
    let transactionId: String
    let blockHeight: String
}

extension TxDetailInfo {
    init(tx: Transaction, state: State) {
        amount = tx.amountDescription(isBtcSwapped: false, rate: state.currentRate!, maxDigits: state.maxDigits)
        fiatAmount = tx.amountDescription(isBtcSwapped: true, rate: state.currentRate!, maxDigits: state.maxDigits)
        status = tx.confirmationStatus
        memo = tx.comment
        timestamp = tx.longTimestamp
        address = tx.toAddress ?? ""
        // TODO: populate balance, exchange rate fields
        startingBalance = "$5000"
        endingBalance = "$6000"
        exchangeRate = tx.exchangeRate == nil ? "$16000 +14.5%" : String(tx.exchangeRate!)
        transactionId = tx.hash
        blockHeight = tx.blockHeight
    }
}

extension Transaction {
    /// Confirmation status based on transaction status string
    var confirmationStatus: TxConfirmationStatus {
        switch status {
        // TODO: temporary hack, this should be part of Transaction model
        case S.Transaction.pending:
            return .networkReceived
        case S.Transaction.complete:
            return .complete
        default:
            return .confirmedFirstBlock
        }
    }
}
