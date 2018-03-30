//
//  EthTransaction.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2018-01-11.
//  Copyright © 2018 breadwallet LLC. All rights reserved.
//

import Foundation
import BRCore

struct EthTransaction: EthLikeTransaction {
    
    // MARK: Transaction Properties
    
    let currency: CurrencyDef = Currencies.eth
    let hash: String
    let status: TransactionStatus
    let direction: TransactionDirection
    let toAddress: String
    let amount: UInt256
    let timestamp: TimeInterval
    let blockHeight: UInt64
    let confirmations: UInt64
    
    // MARK: ETH-network transaction properties
    
    let fromAddress: String
    let gasPrice: UInt256
    let gasLimit: UInt64
    let gasUsed: UInt64
    let nonce: UInt64
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
        
        if tx.isError {
            status = .invalid
        } else {
            switch tx.confirmations {
            case 0:
                status = .pending
            case 1..<6:
                status = .confirmed
            default:
                status = .complete
            }
        }
        
        hash = tx.hash
        blockHeight = tx.blockNumber
        confirmations = tx.confirmations
        fromAddress = tx.from
        toAddress = tx.to
        gasPrice = tx.gasPrice
        gasLimit = tx.gasLimit
        gasUsed = tx.gasUsed
        nonce = tx.nonce
    }
}
