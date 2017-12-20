//
//  TxDetailInfo.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-12-20.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation

enum TxConfirmationStatus {
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
}

extension TxDetailInfo {
    init(tx: Transaction, state: State) {
        amount = tx.amountDescription(isBtcSwapped: false, rate: state.currentRate!, maxDigits: state.maxDigits)
        fiatAmount = tx.amountDescription(isBtcSwapped: false, rate: state.currentRate!, maxDigits: state.maxDigits)
        status = .networkReceived
        memo = tx.comment
        timestamp = "Jan 1st 1999"
        address = tx.toAddress ?? ""
        startingBalance = "$5000"
        endingBalance = "$6000"
        exchangeRate = "$16000 +14.5%"
    }
}
