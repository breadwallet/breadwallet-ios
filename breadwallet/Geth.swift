//
//  Geth.swift
//  breadwallet
//
//  Created by Aaron Voisine on 9/7/17.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation
import Geth

class GethManager {
    let ctx: GethContext
    let ec: GethEthereumClient
    let addr: GethAddress

    var balance: UInt64 {
        return UInt64(bitPattern: try! ec.getBalanceAt(ctx, account: addr, number: -1).getInt64())
    }

    var maxOutputAmount: UInt64 {
        return balance
    }
    
    var receiveAddress: String {
        return addr.getHex()
    }
    
    init(ethPubKey: [UInt8]) {
        ctx = GethContext()
        ec = GethEthereumClient("https://mainnet.infura.io")
        addr = GethAddress(fromBytes: GethHash(fromBytes: Data(bytes: ethPubKey)).getBytes())
        print("latest block:\(try! ec.getBlockByNumber(ctx, number: -1).getNumber())")
    }
    
    func createTransaction(forAmount: UInt64, toAddress: String) -> GethTransaction {
        let toAddr = GethAddress(fromHex: toAddress)
        return GethTransaction(1, toAddr, GethBigInt(Int64(bitPattern: forAmount)), GethBigInt(0), GethBigInt(0), nil)
    }
    
    func signTx(_ tx: GethTransaction, ethPrivKey: String) -> GethTransaction {
        return tx
    }

    func publishTx(_ tx: GethTransaction) {
    }
}
