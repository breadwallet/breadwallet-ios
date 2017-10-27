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
    let store: Store

    var balance: UInt64 {
        return UInt64(bitPattern: try! ec.getBalanceAt(ctx, account: addr, number: -1).getInt64())
    }
    
    var receiveAddress: String {
        return addr.getHex()
    }

    init(ethPrivKey: String, store: Store) {
        self.store = store
        ctx = GethContext()

        if E.isTestnet {
            ec = GethEthereumClient("https://ropsten.infura.io/QY7ejGXZ1RFGrdXfeXx2")
        } else {
            ec = GethEthereumClient("https://mainnet.infura.io")
        }

        addr = autoreleasepool {
            let ks = GethKeyStore(NSTemporaryDirectory(), scryptN:2, scryptP:1)
            var data = CFDataCreateMutable(secureAllocator, MemoryLayout<UInt256>.stride) as Data
            data.count = MemoryLayout<UInt256>.stride
            var key = BRKey(privKey: ethPrivKey)
            data.withUnsafeMutableBytes({ $0.pointee = key!.secret })
            key!.clean()

            let account: GethAccount
            do {
                account = (try ks?.getAccounts().get(0))!
            } catch {
                account = (try! ks?.importECDSAKey(data, passphrase: ethPrivKey))!
            }

            let address = account.getAddress()
            try? ks?.delete(account, passphrase: ethPrivKey)
            return address!

        }
        
        print("receive address:\(addr.getHex())")
        print("latest block:\(try! ec.getBlockByNumber(ctx, number: -1).getNumber())")
    }

    func maxOutputAmount(toAddress: String) -> UInt64 {
        return balance
    }

    func createTx(forAmount: UInt64, toAddress: String) -> GethTransaction {
        let toAddr = GethAddress(fromHex: toAddress)
        let price = try! ec.suggestGasPrice(ctx)
        return GethTransaction(0, to: toAddr, amount: GethBigInt(Int64(bitPattern: forAmount)), gasLimit: GethBigInt(21000),
                               gasPrice: price, data: nil)
    }
    
    func signTx(_ tx: GethTransaction, ethPrivKey: String) -> GethTransaction {
        return autoreleasepool {
            let ks = GethKeyStore(NSTemporaryDirectory(), scryptN:2, scryptP:1)
            var data = CFDataCreateMutable(secureAllocator, MemoryLayout<UInt256>.stride) as Data
            data.count = MemoryLayout<UInt256>.stride
            var key = BRKey(privKey: ethPrivKey)
            data.withUnsafeMutableBytes({ $0.pointee = key!.secret })
            key!.clean()
            let account = try! ks?.importECDSAKey(data, passphrase: ethPrivKey)
            try? ks?.unlock(account, passphrase: ethPrivKey)
            let chainId = E.isTestnet ? GethBigInt(3) : GethBigInt(1)
            let signedTx = try! ks?.signTx(account, tx: tx, chainID: chainId)
            try? ks?.delete(account, passphrase: ethPrivKey)
            return signedTx!
        }
    }

    func publishTx(_ tx: GethTransaction) {
        do {
            try ec.sendTransaction(ctx, tx:tx)
        } catch let e {
            print("error: \(e)")
        }
    }
}
