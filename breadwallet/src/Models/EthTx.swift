//
//  EthTx.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-10-24.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation
import Geth

struct EthTxList : Codable {
    let status: String
    let message: String
    let result: [EthTx]
}

struct EthTx : Codable {
    let blockNumber: String
    let timeStamp: String
    let value: String
    let from: String
    let to: String
    let confirmations: String
    let hash: String
}

struct TokenBalance : Codable {
    let status: String
    let message: String
    let result: String
}

struct Token {
    let name: String
    let code: String
    let symbol: String
    let address: String
    let decimals: Int
    let abi: String
}

struct EventResponse : Codable {
    let status: String
    let message: String
    let result: [Event]
}

struct Event : Codable {
    let address: String
    let topics: [String]
    let data: String
    let timeStamp: String
    let transactionHash: String
    var isComplete = true

    private enum CodingKeys: String, CodingKey {
        case address
        case topics
        case data
        case timeStamp
        case transactionHash
    }
}

extension Event {
    init(timestamp: String, from: String, to: String, amount: String) {
        let topics = ["",from,to]
        let timestampNumber = GethBigInt(0)
        timestampNumber?.setString(timestamp, base: 10)

        let amountNumber = GethBigInt(0)
        amountNumber?.setString(amount, base: 10)
        self.init(address: "", topics: topics, data: amountNumber!.getString(16), timeStamp: timestampNumber!.getString(16), transactionHash: "", isComplete: false)
        self.isComplete = false
    }
}
