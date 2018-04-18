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
    
    public func getBalance(address: EthAddress, handler: @escaping (JSONRPCResult<Quantity>) -> Void) {
        send(rpcRequest: JSONRPCRequest(method: "eth_getBalance", params: JSONRPCParams([address, "latest"])), handler: handler)
    }
    
    public func getGasPrice(handler: @escaping (JSONRPCResult<Quantity>) -> Void) {
        send(rpcRequest: JSONRPCRequest(method: "eth_gasPrice", params: JSONRPCParams([])), handler: handler)
    }
    
    public func estimateGas(transaction: TransactionParams, handler: @escaping (JSONRPCResult<Quantity>) -> Void) {
        send(rpcRequest: JSONRPCRequest(method: "eth_estimateGas", params: JSONRPCParams([transaction, "pending"])), handler: handler)
    }
    
    public func sendRawTransaction(rawTx: String, handler: @escaping (JSONRPCResult<String>) -> Void) {
        send(rpcRequest: JSONRPCRequest(method: "eth_sendRawTransaction", params: JSONRPCParams([rawTx])), handler: handler)
    }

    public func getEthTxList(address: EthAddress, handler: @escaping (APIResult<[EthTx]>)->Void) {
        let req = URLRequest(url: url("/ethq/\(network)/query?module=account&action=txlist&address=\(address)&sort=desc"))
        send(apiRequest: req, handler: handler)
    }
    
    // MARK: Tokens
    
    public func getTokenBalance(address: EthAddress, token: ERC20Token, handler: @escaping (APIResult<Quantity>) -> Void) {
        let req = URLRequest(url: url("/ethq/\(network)/query?module=account&action=tokenbalance&address=\(address)&contractaddress=\(token.address)"))
        send(apiRequest: req, handler: handler)
    }
    
    public func getTokenTransactions(address: EthAddress, token: ERC20Token, handler: @escaping (APIResult<[EthLogEvent]>) -> Void) {
        let accountAddress = address.paddedHexString
        //        let req = URLRequest(url: url("/ethq/\(network)/query?module=logs&action=getLogs&fromBlock=0&toBlock=latest&address=\(token.address)&topic0=\(ERC20Token.transferEventSignature)&topic1=\(accountAddress)&topic1_2_opr=or&topic2=\(accountAddress)"))

        let host = E.isTestnet ? "ropsten.etherscan.io" : "api.etherscan.io"
        let string = "https://\(host)/api?module=logs&action=getLogs&fromBlock=0&toBlock=latest&address=\(token.address)&topic1=\(accountAddress)&topic1_2_opr=or&topic2=\(accountAddress)&topic0=\(ERC20Token.transferEventSignature)"
        let req = URLRequest(url: URL(string: string)!)
        
        send(apiRequest: req, handler: handler)
    }

    // MARK: -
    
    private func send<ResultType>(rpcRequest: JSONRPCRequest, handler: @escaping (JSONRPCResult<ResultType>) -> Void) {
        var encodedData: Data
        do {
            encodedData = try JSONEncoder().encode(rpcRequest)
        } catch (let jsonError) {
            return handler(.error(.jsonError(error: jsonError)))
        }
        
        var req = URLRequest(url: url("/ethq/\(network)/proxy"))
        req.httpMethod = "POST"
        req.httpBody = encodedData
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        
        dataTaskWithRequest(req, authenticated: true, retryCount: 0) { (data, response, error) in
            guard error == nil else {
                return handler(.error(.httpError(error: error)))
            }
            guard let data = data else {
                return handler(.error(.httpError(error: nil)))
            }
            
            var rpcResponse: JSONRPCResponse<ResultType>
            
            do {
                rpcResponse = try JSONRPCResponse<ResultType>.from(data: data)
                if let rpcError = rpcResponse.error {
                    handler(.error(.rpcError(error: rpcError)))
                } else {
                    handler(.success(rpcResponse.result!))
                }
            } catch (let jsonError) {
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
            
            do {
                let apiResponse = try APIResponse<ResultType>.from(data: data)
                handler(APIResult<ResultType>.success(apiResponse.result))
            } catch (let jsonError) {
                print("[API] JSON error: \(jsonError)")
                handler(APIResult<ResultType>.error(jsonError))
            }
        }).resume()
    }
    
    private var network: String {
        return (E.isTestnet || E.isRunningTests) ? "ropsten" : "mainnet"
    }
}
