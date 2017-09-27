//
//  Geth.swift
//  breadwallet
//
//  Created by Aaron Voisine on 9/7/17.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation
import Geth
import BRCore

class GethManager {
    let ctx: GethContext
    let ec: GethEthereumClient
    let addr: GethAddress

    var balance: UInt64 {
        return UInt64(bitPattern: try! ec.getBalanceAt(ctx, account: addr, number: -1).getInt64())
    }
    
    var receiveAddress: String {
        return addr.getHex()
    }
    
    //init(ethPubKey: [UInt8]) {
    init(ethPrivKey: String) {
        ctx = GethContext()
        ec = GethEthereumClient("https://mainnet.infura.io")
        //ec = GethEthereumClient("https://ropsten.infura.io") // testnet

        //addr = GethAddress(fromBytes: GethHash(fromBytes: Data(bytes: ethPubKey)).getBytes())
        addr = autoreleasepool {
            let ks = GethKeyStore(NSTemporaryDirectory(), scryptN:1, scryptP:1)
            var data = CFDataCreateMutable(secureAllocator, MemoryLayout<UInt256>.stride) as Data
            data.count = MemoryLayout<UInt256>.stride
            var key = BRKey(privKey: ethPrivKey)
            data.withUnsafeMutableBytes({ $0.pointee = key!.secret })
            key!.clean()
            let account = try! ks?.importECDSAKey(data, passphrase: ethPrivKey)
            let address = account!.getAddress()
            try? ks?.delete(account!, passphrase: ethPrivKey)
            return address!
        }
        
        print("latest block:\(try! ec.getBlockByNumber(ctx, number: -1).getNumber())")
    }
    
    func maxOutputAmount(toAddress: String) -> UInt64 {
        return balance
    }

    func createTx(forAmount: UInt64, toAddress: String) -> GethTransaction {
        let toAddr = GethAddress(fromHex: toAddress)
        return GethTransaction(1, to: toAddr, amount: GethBigInt(Int64(bitPattern: forAmount)), gasLimit: GethBigInt(0),
                               gasPrice: GethBigInt(0), data: nil)
    }
    
    func signTx(_ tx: GethTransaction, ethPrivKey: String) -> GethTransaction {
        return autoreleasepool {
            let ks = GethKeyStore(NSTemporaryDirectory(), scryptN:1, scryptP:1)
            var data = CFDataCreateMutable(secureAllocator, MemoryLayout<UInt256>.stride) as Data
            data.count = MemoryLayout<UInt256>.stride
            var key = BRKey(privKey: ethPrivKey)
            data.withUnsafeMutableBytes({ $0.pointee = key!.secret })
            key!.clean()
            let account = try! ks?.importECDSAKey(data, passphrase: ethPrivKey)
            let signedTx = try! ks?.signTx(account, tx: tx, chainID: GethBigInt(0))
            try? ks?.delete(account, passphrase: ethPrivKey)
            return signedTx!
        }
    }

    func publishTx(_ tx: GethTransaction) {
        try? ec.sendTransaction(ctx, tx:tx)
    }
}
