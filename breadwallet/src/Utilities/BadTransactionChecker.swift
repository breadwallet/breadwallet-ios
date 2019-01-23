//
//  BadTransactionChecker.swift
//  breadwallet
//
//  Created by Ray Vander Veen on 2019-01-21.
//  Copyright © 2019 breadwallet LLC. All rights reserved.
//

import Foundation
import BRCore

//
// Handles detection of bad (invalid) transactions.
//
class BadTransactionChecker {
    
    var loggedBadTransactionHashes: [String] = [String]()
    
    var badTransactionCount: Int {
        return loggedBadTransactionHashes.count
    }
    
    func alreadyLogged(_ transaction: Transaction) -> Bool {
        return loggedBadTransactionHashes.contains(transaction.hash)
    }
    
    func addBadTransaction(tx: Transaction) {
        loggedBadTransactionHashes.append(tx.hash)
    }
    
    // Checks for bad transactions that have not been encountered previously, and invokes the callback
    // with any new transactions.
    public func checkTransactions(_ transactions: [Transaction], _ callback: (([Transaction]) -> Void)) {
        let badTransactions: [Transaction] = transactions.filter { return !($0.isValid) }
        
        guard !badTransactions.isEmpty else {
            callback([])
            return
        }
        
        let notAlreadyLogged: [Transaction] = badTransactions.filter { return !alreadyLogged($0) }

        // add the tx's not already logged, then report back
        notAlreadyLogged.forEach { addBadTransaction(tx: $0) }

        callback(notAlreadyLogged)
    }
}
