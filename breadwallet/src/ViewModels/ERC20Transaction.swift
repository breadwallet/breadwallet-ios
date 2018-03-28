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
    let blockHeight: UInt64 = 0 // TODO
    let confirmations: UInt64 = 0 // TODO
    let isValid: Bool = true // TODO
    
    // MARK: ETH-network transaction properties
    
    let fromAddress: String
    //TODO:ERC20
    let gasPrice: UInt256 = 0
    let gasLimit: UInt64 = 0
    let gasUsed: UInt64 = 0
   
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
        let ts = UInt64(event.timeStamp, radix: 16)
        self.timestamp = TimeInterval(ts ?? 0)
        self.hash = event.transactionHash
        self.amount = UInt256(hexString: event.data)
        
        if event.isComplete {
            self.status = .complete
        } else {
            self.status = .pending
        }
    }
}
