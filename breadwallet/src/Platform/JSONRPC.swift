//
//  JSONRPC.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2018-03-12.
//  Copyright © 2018 breadwallet LLC. All rights reserved.
//

import Foundation
import BRCore

public typealias Quantity = UInt256
public typealias EthAddress = String

// MARK: - Requests

public struct JSONRPCRequest: Encodable {
    public let id: Int = Int(floor(Date().timeIntervalSince1970))
    public let jsonrpc: String = "2.0" // version string
    public let method: String
    public let params: JSONRPCParams
}

// MARK: Request Params

public struct JSONRPCParams: Encodable {
    public var params = [Encodable]()
    
    public init(_ params: [Encodable]) {
        self.params = params
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        for par in params {
            if let p = par as? TransactionParams {
                try container.encode(p)
            } else if let p = par as? ListTransactionsParams {
                try container.encode(p)
            } else if let p = par as? String {
                try container.encode(p)
            } else if let p = par as? Bool {
                try container.encode(p)
            } else if let p = par as? Int {
                try container.encode(p)
            }
        }
    }
}

public struct TransactionParams: Encodable {
    public var from: String
    public var to: String
    public var value: Amount?
    public var gas: String?
    public var gasPrice: String?
    public var data: String?
    
    public init(from: String, to: String) {
        self.from = from
        self.to = to
    }
}

public struct ListTransactionsParams: Codable {
    public var fromBlock: Quantity
    public var toBlock: Quantity
    public var address: EthAddress
}

// Encodes Amount as a hex value in base units for use in Ethereum JSON-RPC calls
extension Amount: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(core.string(base: 16, preface: "0x"))
    }
}

// MARK: - Response

//public struct JSONRPCResponse<ResultType: Codable>: Decodable {
public struct JSONRPCResponse<ResultType: Codable>: Decodable {
    public let id: Int = Int(floor(Date().timeIntervalSince1970))
    public let jsonrpc: String
    public let result: ResultType?
    public let error: JSONRPCError.RPCError?
    
    static func from(data: Data) throws -> JSONRPCResponse<ResultType> {
        return try JSONDecoder().decode(JSONRPCResponse<ResultType>.self, from: data)
    }
}

public enum JSONRPCResult<ResultType: Codable> {
    case success(ResultType)
    case error(JSONRPCError)
}

public enum JSONRPCError: Error {
    case httpError(error: Error?)
    case jsonError(error: Error?)
    case rpcError(error: RPCError)
    
    public struct RPCError: Codable, Error {
        let code: Int
        let message: String
    }
}

// MARK: 

public struct APIResponse<ResultType: Codable>: Decodable {
    public let status: String
    public let message: String
    public let result: ResultType
    
    static func from(data: Data) throws -> APIResponse<ResultType> {
        return try JSONDecoder().decode(APIResponse<ResultType>.self, from: data)
    }
}

public enum APIResult<ResultType: Codable> {
    case success(ResultType)
    case error(Error)
}

public struct HTTPError: Error {
    let code: Int
}
