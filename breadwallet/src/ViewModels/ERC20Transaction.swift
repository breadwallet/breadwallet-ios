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
    
    // MARK: ETH-network transaction properties
    
    let fromAddress: String
    let gasPrice: UInt256
    let gasLimit: UInt64 = 0
    let gasUsed: UInt64
   
    // MARK: ERC20-specific properties
    
    let event: EthLogEvent
    
    // MARK: - Init
    
    init(event: EthLogEvent, accountAddress: String, token: ERC20Token) {
        self.currency = token
        self.event = event
        
        //let ts = UInt64(event.timeStamp, radix: 16)
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
            return
        }
        
        self.fromAddress = event.topics[1].unpaddedHexString
        self.toAddress = event.topics[2].unpaddedHexString
        
        if accountAddress.lowercased() == fromAddress.lowercased() {
            self.direction = .sent
        } else {
            self.direction = .received
        }
        
        self.amount = UInt256(hexString: event.data)
        
        //TODO:ERC20 confirmations?
        self.status = event.isLocal ? .pending : .complete
    }
}
