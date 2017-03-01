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
    func makeTransactionViewModels(blockHeight: UInt32) -> [Transaction] {
        return transactions.flatMap{ $0 }.sorted{ $0.pointee.timestamp > $1.pointee.timestamp }.map {
            return Transaction($0, wallet: self, blockHeight: blockHeight)
        }
    }
}
