//
//  BRAPIClient+Ethereum.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2018-03-12.
//  Copyright © 2018 breadwallet LLC. All rights reserved.
//

import Foundation
import BRCore

extension BRAPIClient {
    
    // MARK: ETH
    
    public func getBalance(address: EthAddress, handler: @escaping (JSONRPCResult<String>) -> Void) {
        send(rpcRequest: JSONRPCRequest(method: "eth_getBalance", params: JSONRPCParams([address, "latest"])), handler: handler)
    }
    
    public func getLastBlockNumber(handler: @escaping (JSONRPCResult<String>) -> Void) {
        send(rpcRequest: JSONRPCRequest(method: "eth_blockNumber", params: JSONRPCParams(["latest"])), handler: handler)
    }
    
    public func getTransactionCount(address: EthAddress, handler: @escaping (JSONRPCResult<String>) -> Void) {
        send(rpcRequest: JSONRPCRequest(method: "eth_getTransactionCount", params: JSONRPCParams([address, "latest"])), handler: handler)
    }
    
    public func getGasPrice(handler: @escaping (JSONRPCResult<Quantity>) -> Void) {
        send(rpcRequest: JSONRPCRequest(method: "eth_gasPrice", params: JSONRPCParams([])), handler: handler)
    }
    
    public func estimateGas(transaction: TransactionParams, handler: @escaping (JSONRPCResult<Quantity>) -> Void) {
        send(rpcRequest: JSONRPCRequest(method: "eth_estimateGas", params: JSONRPCParams([transaction])), handler: handler)
    }
    
    public func sendRawTransaction(rawTx: String, handler: @escaping (JSONRPCResult<String>) -> Void) {
        send(rpcRequest: JSONRPCRequest(method: "eth_sendRawTransaction", params: JSONRPCParams([rawTx])), handler: handler)
    }

    public func getEthTxList(address: EthAddress, fromBlock: UInt64, toBlock: UInt64, handler: @escaping (APIResult<[EthTxJSON]>) -> Void) {
        let blockParams = "&startblock=\(fromBlock)&endblock=\(toBlock)"
        let req = URLRequest(url: url("/ethq/\(network)/query?module=account&action=txlist&address=\(address)\(blockParams)&sort=desc"))
        send(apiRequest: req, handler: handler)
    }
    
    // MARK: Tokens
    
    public func getTokenBalance(address: EthAddress, token: ERC20Token, handler: @escaping (APIResult<String>) -> Void) {
        let req = URLRequest(url: url("/ethq/\(network)/query?module=account&action=tokenbalance&address=\(address)&contractaddress=\(token.address)"))
        send(apiRequest: req, handler: handler)
    }
    
    public func getTokenTransferLogs(address: EthAddress,
                                     contractAddress: String?,
                                     fromBlock: UInt64,
                                     toBlock: UInt64,
                                     handler: @escaping (APIResult<[EthLogEventJSON]>) -> Void) {
        let accountAddress = address.paddedHexString
        let tokenAddressParam = (contractAddress != nil) ? "&address=\(contractAddress!)" : ""
        let blockParams = "&fromBlock=\(fromBlock)&toBlock=\(toBlock)"
        let topicParams = "&topic0=\(ERC20Token.transferEventSignature)&topic1=\(accountAddress)&topic1_2_opr=or&topic2=\(accountAddress)"
        let req = URLRequest(url: url("/ethq/\(network)/query?module=logs&action=getLogs\(blockParams)\(tokenAddressParam)\(topicParams)"))
        send(apiRequest: req, handler: handler)
    }
    
    // MARK: Token List
    
    public func getTokenList(handler: @escaping (APIResult<[ERC20Token]>) -> Void) {
        let req = URLRequest(url: url("/currencies?type=erc20"))
        send(request: req, handler: handler)
    }
    
    public func getToken(withSaleAddress saleAddress: String, handler: @escaping (APIResult<[ERC20Token]>) -> Void) {
        let req = URLRequest(url: url("/currencies?saleAddress=\(saleAddress.lowercased())"))
        send(request: req, handler: handler)
    }

    // MARK: -
    
    private func send<ResultType>(rpcRequest: JSONRPCRequest, handler: @escaping (JSONRPCResult<ResultType>) -> Void) {
        var encodedData: Data
        do {
            encodedData = try JSONEncoder().encode(rpcRequest)
        } catch let jsonError {
            return handler(.error(.jsonError(error: jsonError)))
        }
        
        var req = URLRequest(url: url("/ethq/\(network)/proxy"))
        req.httpMethod = "POST"
        req.httpBody = encodedData
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        
        dataTaskWithRequest(req, authenticated: true, retryCount: 0) { (data, _, error) in
            guard error == nil else {
                return handler(.error(.httpError(error: error)))
            }
            guard let data = data else {
                return handler(.error(.httpError(error: nil)))
            }
            
            do {
                let rpcResponse = try JSONRPCResponse<ResultType>.from(data: data)
                if let rpcError = rpcResponse.error {
                    handler(.error(.rpcError(error: rpcError)))
                } else {
                    handler(.success(rpcResponse.result!))
                }
            } catch let jsonError {
                handler(.error(.jsonError(error: jsonError)))
            }
            }.resume()
    }
    
    private func send<ResultType>(apiRequest: URLRequest, handler: @escaping (APIResult<ResultType>) -> Void) {
        dataTaskWithRequest(apiRequest, authenticated: true, retryCount: 0, handler: { data, response, error in
            guard error == nil, let data = data else {
                print("[API] HTTP error: \(error!)")
                return handler(APIResult<ResultType>.error(error!))
            }
            guard let statusCode = response?.statusCode, statusCode >= 200 && statusCode < 300 else {
                return handler(APIResult<ResultType>.error(HTTPError(code: response?.statusCode ?? 0)))
            }
            
            do {
                let apiResponse = try APIResponse<ResultType>.from(data: data)
                handler(APIResult<ResultType>.success(apiResponse.result))
            } catch let jsonError {
                print("[API] JSON error: \(jsonError)")
                handler(APIResult<ResultType>.error(jsonError))
            }
        }).resume()
    }
    
    private func send<ResultType>(request: URLRequest, handler: @escaping (APIResult<ResultType>) -> Void) {
        dataTaskWithRequest(request, authenticated: true, retryCount: 0, handler: { data, response, error in
            guard error == nil, let data = data else {
                print("[API] HTTP error: \(error!)")
                return handler(APIResult<ResultType>.error(error!))
            }
            guard let statusCode = response?.statusCode, statusCode >= 200 && statusCode < 300 else {
                return handler(APIResult<ResultType>.error(HTTPError(code: response?.statusCode ?? 0)))
            }
            
            do {
                let result = try JSONDecoder().decode(ResultType.self, from: data)
                handler(APIResult<ResultType>.success(result))
            } catch let jsonError {
                print("[API] JSON error: \(jsonError)")
                handler(APIResult<ResultType>.error(jsonError))
            }
        }).resume()
    }
    
    private var network: String {
        return (E.isTestnet || E.isRunningTests) ? "ropsten" : "mainnet"
    }
}

// MARK: JSON Types

/// Maps to JSON model of ETH transaction
public struct EthTxJSON: Codable {
    let hash: String
    let nonce: String
    let blockHash: String
    let blockNumber: String
    let transactionIndex: String
    let from: String
    let to: String
    let value: String
    let gasPrice: String
    let gas: String // gasLimit
    let gasUsed: String
    let input: String // data
    let timeStamp: String
    let confirmations: String
    let contractAddress: String
    let isError: String
}

// MARK: -

/// Maps to JSON model of a log event
public struct EthLogEventJSON: Codable {
    public let address: String
    public let topics: [String]
    public let data: String
    public let blockNumber: String
    public let gasPrice: String
    public let gasUsed: String
    public let timeStamp: String
    public let transactionHash: String
    public let transactionIndex: String
    public let logIndex: String
}
