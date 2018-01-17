//
//  ERC20Transaction.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2018-01-11.
//  Copyright © 2018 breadwallet LLC. All rights reserved.
//

import Foundation

struct ERC20Transaction: EthLikeTransaction {
    
    // MARK: Transaction Properties
    
    let currency: CurrencyDef
    let hash: String
    let status: TransactionStatus
    let direction: TransactionDirection
    let toAddress: String
    let timestamp: TimeInterval
    let blockHeight: UInt64 = 0 // TODO
    let confirmations: UInt64 = 0 // TODO
    let isValid: Bool = true // TODO
    
    // MARK: ETH-network transaction properties
    
    let amount: GethBigInt
    let fromAddress: String
    
    // MARK: ERC20-specific properties
    
    let event: Event
    
    // MARK: - Init
    
    init(event: Event, address: String, token: ERC20Token) {
        self.currency = token
        self.event = event
        
        //FIXME
        var address0: String = ""
        var address1: String = ""
        if event.topics.count >= 3 {
            address0 = event.topics[1].replacingOccurrences(of: "000000000000000000000000", with: "")
            address1 = event.topics[2].replacingOccurrences(of: "000000000000000000000000", with: "")
        }
        
        if address.lowercased() == address0.lowercased() {
            self.direction = .sent
            self.toAddress = address1
            self.fromAddress = address0
        } else {
            self.direction = .received
            self.toAddress = address1
            self.fromAddress = address0
        }
        let timestampWrapper = GethBigInt(0)
        timestampWrapper.setString(event.timeStamp.replacingOccurrences(of: "0x", with: ""), base: 16)
        self.timestamp = TimeInterval(timestampWrapper.getInt64())
        self.hash = event.transactionHash
        
        let amount = GethBigInt(0)
        amount.setString(event.data.replacingOccurrences(of: "0x", with: ""), base: 16)
        self.amount = amount
        
        if event.isComplete {
            self.status = .complete
        } else {
            self.status = .pending
        }
    }
}
