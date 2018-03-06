//
//  EthTransaction.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2018-01-11.
//  Copyright © 2018 breadwallet LLC. All rights reserved.
//

import Foundation

struct EthTransaction: EthLikeTransaction {
    
    // MARK: Transaction Properties
    
    let currency: CurrencyDef = Currencies.eth
    let hash: String
    let status: TransactionStatus
    let direction: TransactionDirection
    let toAddress: String
    let timestamp: TimeInterval
    let blockHeight: UInt64
    let confirmations: UInt64
    let isValid: Bool
    
    // MARK: ETH-network transaction properties
    
    let amount: GethBigInt
    let fromAddress: String
    
    // MARK: ETH-specific properties
    
    let tx: EthTx
    
    // MARK: - Init
    
    init(tx: EthTx, address: String) {
        self.init(tx: tx, accountAddress: address)
    }
    
    init(tx: EthTx, accountAddress: String) {
        self.tx = tx
        amount = tx.value
        timestamp = tx.timeStamp
        direction = tx.to.lowercased() == accountAddress.lowercased() ? .received : .sent
        isValid = !tx.isError
        
        if isValid {
            if Int(tx.confirmations) == 0 {
                status = .pending
            } else {
                status = .complete
            }
        } else {
            status = .invalid
        }
        
        hash = tx.hash
        blockHeight = tx.blockNumber
        confirmations = tx.confirmations
        fromAddress = tx.from
        toAddress = tx.to
    }
}
