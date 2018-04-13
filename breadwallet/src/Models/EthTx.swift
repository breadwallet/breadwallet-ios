//
//  EthTx.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-10-24.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation
import BRCore

/// Maps to JSON model of ETH transaction
public struct EthTx {
    let blockNumber: UInt64
    let timeStamp: TimeInterval
    let value: UInt256
    let gasPrice: UInt256
    let gasLimit: UInt64
    let gasUsed: UInt64
    let from: String
    let to: String
    let confirmations: UInt64
    let nonce: UInt64
    let hash: String
    let isError: Bool
    var rawTx: String? = nil // TODO:ERC20 cleanup
    
    private enum CodingKeys: String, CodingKey {
        case blockNumber
        case timeStamp
        case value
        case gasPrice
        case gasLimit = "gas"
        case gasUsed
        case from
        case to
        case confirmations
        case nonce
        case hash
        case isError
    }
}

extension EthTx: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        blockNumber = try container.decodeFromString(UInt64.self, forKey: .blockNumber)
        confirmations = try container.decodeFromString(UInt64.self, forKey: .confirmations)
        nonce = try container.decodeFromString(UInt64.self, forKey: .nonce)
        timeStamp = try container.decodeFromString(TimeInterval.self, forKey: .timeStamp)
        value = try container.decode(UInt256.self, forKey: .value)
        gasPrice = try container.decode(UInt256.self, forKey: .gasPrice)
        gasLimit = try container.decodeFromString(UInt64.self, forKey: .gasLimit)
        gasUsed = try container.decodeFromString(UInt64.self, forKey: .gasUsed)
        from = try container.decode(String.self, forKey: .from)
        to = try container.decode(String.self, forKey: .to)
        hash = try container.decode(String.self, forKey: .hash)
        
        let isErrorString = try container.decode(String.self, forKey: .isError)
        isError = (isErrorString == "0") ? false : true
    }
}

extension EthTx: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(String(blockNumber), forKey: .blockNumber)
        try container.encode(String(confirmations), forKey: .confirmations)
        try container.encode(String(nonce), forKey: .nonce)
        try container.encode(String(timeStamp), forKey: .timeStamp)
        try container.encode(value, forKey: .value)
        try container.encode(gasPrice, forKey: .gasPrice)
        try container.encode(String(gasLimit), forKey: .gasLimit)
        try container.encode(String(gasUsed), forKey: .gasUsed)
        try container.encode(from, forKey: .from)
        try container.encode(to, forKey: .to)
        try container.encode(hash, forKey: .hash)
        try container.encode(isError ? "1" : "0", forKey: .isError)
    }
}

// MARK: -

//TODO:ERC20 unused
struct Contract {
    let address: String
    let abi: String
}

/// Maps to JSON model of a log event
public struct EthLogEvent {
    public let address: String
    public let topics: [String]
    public let data: String
    public let blockNumber: UInt64
    public let gasPrice: UInt256
    public let gasUsed: UInt64
    public let timeStamp: TimeInterval
    public let transactionHash: String
//    public let transactionIndex: String
//    public let logIndex: String
    public var isLocal = false

    private enum CodingKeys: String, CodingKey {
        case address
        case topics
        case data
        case blockNumber
        case gasPrice
        case gasUsed
        case timeStamp
        case transactionHash
    }
    
//    init(timestamp: String, from: String, to: String, amount: UInt256) {
//        let topics = ["",from,to]
//        self.init(address: "",
//                  topics: topics,
//                  data: amount.hexString,
//                  timeStamp: UInt256(string: timestamp).hexString,
//                  transactionHash: "",
//                  isLocal: true)
//    }
}

extension EthLogEvent: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        address = try container.decode(String.self, forKey: .address)
        topics = try container.decode([String].self, forKey: .topics)
        data = try container.decode(String.self, forKey: .data)
        blockNumber = try container.decodeFromHexString(UInt64.self, forKey: .blockNumber)
        gasPrice = try container.decode(UInt256.self, forKey: .gasPrice)
        gasUsed = try container.decodeFromHexString(UInt64.self, forKey: .gasUsed)
        let seconds = try container.decodeFromHexString(UInt64.self, forKey: .timeStamp)
        timeStamp = TimeInterval(seconds)
        transactionHash = try container.decode(String.self, forKey: .transactionHash)
        
        isLocal = false
    }
}

extension EthLogEvent: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(address, forKey: .address)
        try container.encode(topics, forKey: .topics)
        try container.encode(data, forKey: .data)
        try container.encode(String(blockNumber, radix: 16), forKey: .blockNumber)
        try container.encode(gasPrice, forKey: .gasPrice)
        try container.encode(String(gasUsed, radix: 16), forKey: .gasUsed)
        try container.encode(String(UInt64(timeStamp), radix: 16), forKey: .timeStamp)
        try container.encode(transactionHash, forKey: .transactionHash)
    }
}
