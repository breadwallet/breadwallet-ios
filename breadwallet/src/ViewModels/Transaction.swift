//
//  Transaction.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-11-17.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import Foundation

struct Transaction {
    let transaction: String
    let status: String
    let comment: String
    let timestamp: String
}

extension Transaction {
    static var random: Transaction {
        return Transaction(transaction: "Test", status: "Waiting", comment: "Sushi", timestamp: "3m")
    }
}
