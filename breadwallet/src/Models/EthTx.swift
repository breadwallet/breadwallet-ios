//
//  EthTx.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-10-24.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation

struct EthTxList : Codable {
    let status: String
    let message: String
    let result: [EthTx]
}

struct EthTx {
    let blockNumber: UInt64
    let timeStamp: TimeInterval
    let value: GethBigInt
    let from: String
    let to: String
    let confirmations: UInt64
    let hash: String
    let isError: Bool
    
    private enum CodingKeys: String, CodingKey {
        case blockNumber
        case timeStamp
        case value
        case from
        case to
        case confirmations
        case hash
        case isError
    }
}

extension EthTx: Decodable {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        blockNumber = try container.decodeFromString(UInt64.self, forKey: .blockNumber)
        confirmations = try container.decodeFromString(UInt64.self, forKey: .confirmations)
        timeStamp = try container.decodeFromString(TimeInterval.self, forKey: .timeStamp)
        let valueString = try container.decode(String.self, forKey: .value)
        let value = GethBigInt(0)
        value.setString(valueString, base: 10)
        self.value = value
        from = try container.decode(String.self, forKey: .from)
        to = try container.decode(String.self, forKey: .to)
        hash = try container.decode(String.self, forKey: .hash)
        
        let isErrorString = try container.decode(String.self, forKey: .isError)
        isError = (isErrorString == "0") ? false : true
    }
}

extension EthTx: Encodable {
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(String(blockNumber), forKey: .blockNumber)
        try container.encode(String(confirmations), forKey: .confirmations)
        try container.encode(String(timeStamp), forKey: .timeStamp)
        try container.encode(value.stringValue, forKey: .value)
        try container.encode(from, forKey: .from)
        try container.encode(to, forKey: .to)
        try container.encode(hash, forKey: .hash)
        try container.encode(isError ? "1" : "0", forKey: .isError)
    }
}

struct TokenBalance : Codable {
    let status: String
    let message: String
    let result: String
}

struct Contract {
    let address: String
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
        timestampNumber.setString(timestamp, base: 10)

        let amountNumber = GethBigInt(0)
        amountNumber.setString(amount, base: 10)
        self.init(address: "", topics: topics, data: amountNumber.getString(16), timeStamp: timestampNumber.getString(16), transactionHash: "", isComplete: false)
        self.isComplete = false
    }
}
