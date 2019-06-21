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
    
    let currency: Currency = Currencies.eth
    let hash: String
    let status: TransactionStatus
    let direction: TransactionDirection
    let toAddress: String
    let amount: UInt256
    let timestamp: TimeInterval
    let blockHeight: UInt64
    let confirmations: UInt64
    let metaDataContainer: MetaDataContainer?
    let kvStore: BRReplicatedKVStore?
    
    // MARK: ETH-network transaction properties
    
    let fromAddress: String
    let gasPrice: UInt256
    let gasLimit: UInt64
    let gasUsed: UInt64
    let nonce: UInt64
    
    // MARK: - Init
    
    init(tx: EthereumTransfer, accountAddress: String, kvStore: BRReplicatedKVStore?, rate: Rate?) {
        
        switch tx.confirmations {
        case 0:
            status = .pending
        case 1..<6:
            status = .confirmed
        default:
            status = .complete
        }
        
        if status == .pending && tx.blockTimestamp == 0 {
            timestamp = Date().timeIntervalSince1970
        } else {
            timestamp = TimeInterval(tx.blockTimestamp)
        }
        
        hash = tx.hash
        blockHeight = tx.blockNumber
        amount = tx.amount
        fromAddress = tx.sourceAddress
        toAddress = tx.targetAddress
        direction = tx.targetAddress.lowercased() == accountAddress.lowercased() ? .received : .sent
        confirmations = tx.confirmations
        gasPrice = tx.gasPrice
        gasLimit = tx.gasLimit
        gasUsed = tx.gasUsed
        nonce = tx.nonce
        
        // metadata
        self.kvStore = kvStore
        let key = UInt256(hexString: tx.hash).txKey
        if let kvStore = kvStore {
            metaDataContainer = MetaDataContainer(key: key, kvStore: kvStore)
            if let rate = rate,
                confirmations < 6 && direction == .received {
                metaDataContainer!.createMetaData(tx: self, rate: rate)
            }
        } else {
            metaDataContainer = nil
        }
    }
}
