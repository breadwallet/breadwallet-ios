//
//  Geth.swift
//  breadwallet
//
//  Created by Aaron Voisine on 9/7/17.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation
import BRCore

class GethManager {
    let context: GethContext
    let client: GethEthereumClient
    let address: GethAddress

    var balance: GethBigInt {
        return GethBigInt(0)
    }

    private var balanceCache: GethBigInt? = nil
    
    var receiveAddress: String {
        return ""
    }
    private let gasLimit: Int64 = 36000
    private let transferGasLimit: Int64 = 150000
    private let crowdsaleGasLimit: Int64 = 150000

    init(ethPubKey: [UInt8]) {
        self.context = GethContext()

        if E.isTestnet {
            self.client = GethEthereumClient("https://ropsten.infura.io/")
        } else {
            self.client = GethEthereumClient("https://mainnet.infura.io")
        }

        var md32 = [UInt8](repeating: 0, count: 32)
        BRKeccak256(&md32, ethPubKey, ethPubKey.count)
        self.address = GethAddress(fromBytes: Data(md32[12...]))
        
        //print("receive address:\(address.getHex())")
        //print("latest block:\(try! client.getBlockByNumber(context, number: -1).getNumber())")
    }

    func maxOutputAmount(toAddress: String) -> GethBigInt {
        return balance
    }

    func createTx(forAmount: GethBigInt, toAddress: String, nonce: Int64, isCrowdsale: Bool) -> GethTransaction {
        let toAddr = GethAddress(fromHex: toAddress)
        let price = client.suggestGasPrice()
        return GethTransaction(nonce, to: toAddr, amount: forAmount, gasLimit: GethBigInt((isCrowdsale ? crowdsaleGasLimit : gasLimit)),
                               gasPrice: price, data: nil)
    }

    func fee(isCrowdsale: Bool) -> GethBigInt {
        let price = (client.suggestGasPrice()).getInt64()
        return GethBigInt(Int(price * (isCrowdsale ? crowdsaleGasLimit : gasLimit)))
    }
    
    func signTx(_ tx: GethTransaction, ethPrivKey: String) -> GethTransaction {
        return autoreleasepool {
            let ks = GethKeyStore(NSTemporaryDirectory(), scryptN:2, scryptP:1)
            var data = CFDataCreateMutable(secureAllocator, MemoryLayout<UInt256>.stride) as Data
            data.count = MemoryLayout<UInt256>.stride
            var key = BRKey(privKey: ethPrivKey)
            data.withUnsafeMutableBytes({ $0.pointee = key!.secret })
            key!.clean()
            let account = ks.importECDSAKey(data, passphrase: ethPrivKey)
            let chainId = E.isTestnet ? GethBigInt(3) : GethBigInt(1)
            let signedTx = ks.signTx(account, tx: tx, chainID: chainId)
            return signedTx
        }
    }

    func publishTx(_ tx: GethTransaction) -> Error? {
        client.sendTransaction(tx:tx)
        return nil
    }

    func transfer(amount: GethBigInt, toAddress: String, privKey: String, token: ERC20Token, nonce: Int) -> Error? {
        return nil
    }
}

extension GethManager {

    func getStartTime(forContractAddress: String) -> Date? {
        guard let startTime = callBigInt(method: "startTime", contractAddress: forContractAddress)?.getString(10) else { return nil }
        guard let timestamp = TimeInterval(startTime) else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }

    func getEndTime(forContractAddress: String) -> Date? {
        guard let endTime = callBigInt(method: "endTime", contractAddress: forContractAddress)?.getString(10) else { return nil }
        guard let timestamp = TimeInterval(endTime) else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }

    func getMinContribution(forContractAddress: String) -> GethBigInt? {
        return callBigInt(method: "minContribution", contractAddress: forContractAddress)
    }

    func getMaxContribution(forContractAddress: String) -> GethBigInt? {
        return callBigInt(method: "maxContribution", contractAddress: forContractAddress)
    }

    func getRate(forContractAddress: String) -> GethBigInt? {
        return callBigInt(method: "rate", contractAddress: forContractAddress)
    }

    func getCap(forContractAddress: String) -> GethBigInt? {
        return callBigInt(method: "cap", contractAddress: forContractAddress)
    }

    func getWeiRaised(forContractAddress: String) -> GethBigInt? {
        return callBigInt(method: "weiRaised", contractAddress: forContractAddress)
    }

    func callBigInt(method: String, contractAddress: String) -> GethBigInt? {
        return nil
    }

    func getToken(forContractAddress: String) -> GethAddress? {
        return nil
    }
}

class Signer : NSObject {

    init(ethPrivKey: String) {
        self.ethPrivKey = ethPrivKey
    }
    let ethPrivKey: String

    func sign(_ p0: GethAddress!, p1: GethTransaction!) throws -> GethTransaction {
        let ks = GethKeyStore(NSTemporaryDirectory(), scryptN:2, scryptP:1)
        var data = CFDataCreateMutable(secureAllocator, MemoryLayout<UInt256>.stride) as Data
        data.count = MemoryLayout<UInt256>.stride
        var key = BRKey(privKey: ethPrivKey)
        data.withUnsafeMutableBytes({ $0.pointee = key!.secret })
        key!.clean()
        let account = ks.importECDSAKey(data, passphrase: ethPrivKey)
        let chainId = E.isTestnet ? GethBigInt(3) : GethBigInt(1)
        let signedTx = ks.signTx(account, tx: p1, chainID: chainId)
        return signedTx
    }
}

extension GethBigInt : Comparable {}

extension GethBigInt {
    var stringValue: String {
        return getString(10)
    }
}

public func ==(lhs: GethBigInt, rhs: GethBigInt) -> Bool {
    return true
}

public func >(lhs: GethBigInt, rhs: GethBigInt) -> Bool {
    guard let lhsDecimal = Decimal(string: lhs.stringValue) else { return false }
    guard let rhsDecimal = Decimal(string: rhs.stringValue) else { return false }
    return lhsDecimal > rhsDecimal
}

public func <(lhs: GethBigInt, rhs: GethBigInt) -> Bool {
    guard let lhsDecimal = Decimal(string: lhs.stringValue) else { return false }
    guard let rhsDecimal = Decimal(string: rhs.stringValue) else { return false }
    return lhsDecimal < rhsDecimal
}

public func >=(lhs: GethBigInt, rhs: GethBigInt) -> Bool {
    guard let lhsDecimal = Decimal(string: lhs.stringValue) else { return false }
    guard let rhsDecimal = Decimal(string: rhs.stringValue) else { return false }
    return lhsDecimal >= rhsDecimal
}

public func <=(lhs: GethBigInt, rhs: GethBigInt) -> Bool {
    guard let lhsDecimal = Decimal(string: lhs.stringValue) else { return false }
    guard let rhsDecimal = Decimal(string: rhs.stringValue) else { return false }
    return lhsDecimal <= rhsDecimal
}

public func -(lhs: GethBigInt, rhs: GethBigInt) -> GethBigInt {
    let lhsDecimal = Decimal(string: lhs.stringValue)!
    let rhsDecimal = Decimal(string: rhs.stringValue)!
    let result = GethBigInt(0)
    result.setString((lhsDecimal - rhsDecimal).description, base: 10)
    return result
}
