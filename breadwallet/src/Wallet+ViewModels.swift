//
//  Wallet+ViewModels.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-01-12.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation
import BRCore

extension BRWallet {
    var transactionViewModels: [Transaction] {
        return transactions.flatMap { $0 }.map {
            return Transaction(amountSent: amountSentByTx($0), amountReceived: amountReceivedFromTx($0), timestamp: $0.pointee.timestamp)
        }
    }
}
