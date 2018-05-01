//
//  ERC20Transaction.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2018-01-11.
//  Copyright © 2018 breadwallet LLC. All rights reserved.
//

import Foundation
import BRCore

struct ERC20Transaction: EthLikeTransaction {
    
    // MARK: Transaction Properties
    
    let currency: CurrencyDef
    let hash: String
    let status: TransactionStatus
    let direction: TransactionDirection
    let toAddress: String
    let amount: UInt256
    let timestamp: TimeInterval
    let blockHeight: UInt64
    let confirmations: UInt64 = 1 // TODO:ERC20
    let metaDataContainer: MetaDataContainer?
    let kvStore: BRReplicatedKVStore?
    
    // MARK: ETH-network transaction properties
    
    let fromAddress: String
    let gasPrice: UInt256
    let gasLimit: UInt64 = 0
    let gasUsed: UInt64
   
    // MARK: ERC20-specific properties
    
    // MARK: - Init
    
    init(event: EthLogEvent, accountAddress: String, token: ERC20Token, latestBlockNumber: UInt64?, kvStore: BRReplicatedKVStore?, rate: Rate?) {
        self.currency = token
        
        self.timestamp = TimeInterval(event.timeStamp)
        self.blockHeight = event.blockNumber
        self.hash = event.transactionHash
        self.gasPrice = event.gasPrice
        self.gasUsed = event.gasUsed
        
        guard event.topics.count >= 3, event.topics[0] == ERC20Token.transferEventSignature else {
            self.fromAddress = ""
            self.toAddress = ""
            self.amount = UInt256(0)
            self.direction = .sent
            self.status = .invalid
            self.kvStore = nil
            self.metaDataContainer = nil
            return
        }
        
        let topics1 = event.topics[1].unpaddedHexString
        let topics2 = event.topics[2].unpaddedHexString
        assert(topics1.isValidEthAddress && topics2.isValidEthAddress)
        self.fromAddress = topics1
        self.toAddress = topics2
        if accountAddress.lowercased() == fromAddress.lowercased() {
            self.direction = .sent
        } else {
            self.direction = .received
        }
        
        self.amount = UInt256(hexString: event.data)
        
        if let latestBlockNumber = latestBlockNumber {
            let confirmations = (latestBlockNumber > event.blockNumber) ? (latestBlockNumber - event.blockNumber) : 0
            if event.isLocal {
                self.status = .pending
            } else {
                switch confirmations {
                case 0:
                    status = .pending
                case 1..<6:
                    status = .confirmed
                default:
                    status = .complete
                }
            }
        } else {
            self.status = event.isLocal ? .pending : .complete
        }
        
        // metadata
        self.kvStore = kvStore
        let key = UInt256(hexString: event.transactionHash).tokenTxKey
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
    
    /// Create a placeholder pending transaction
    init(token: ERC20Token,
         accountAddress: String,
         toAddress: String,
         amount: UInt256,
         timestamp: TimeInterval,
         gasPrice: UInt256,
         hash: String,
         kvStore: BRReplicatedKVStore?) {
        self.currency = token
        self.fromAddress = accountAddress
        self.toAddress = toAddress
        self.amount = amount
        self.gasPrice = gasPrice
        self.gasUsed = 0
        self.blockHeight = 0
        self.hash = hash
        self.timestamp = timestamp
        self.direction = .sent
        self.status = .pending
        self.kvStore = nil
        let key = UInt256(hexString: hash).tokenTxKey
        if let kvStore = kvStore {
            metaDataContainer = MetaDataContainer(key: key, kvStore: kvStore)
        } else {
            metaDataContainer = nil
        }
    }
}
