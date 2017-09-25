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

    init?(ethPubKey: [UInt8], store: Store) {
        ctx = GethContext()
        //ec = GethEthereumClient("https://mainnet.infura.io")
        ec = GethEthereumClient("https://ropsten.infura.io") // testnet
        self.store = store

        let data = Data(bytes: ethPubKey)
        var ethPubKeyHex: String = data.hexString
        ethPubKeyHex = ethPubKeyHex.substringFromStart(to: 64)

        //This will fail if input isn't 64 chars
        guard var hash = GethHash(fromHex: ethPubKeyHex).getHex() else { return nil }
        hash = hash.replacingOccurrences(of: "0x", with: "")
        hash = hash.substringFromStart(to: 40)

        //This will fail if input isn't 40 chars
        guard let address = GethAddress(fromHex: hash) else { return nil }
        addr = address

        if let testAddress = GethAddress(fromHex: "53Bb60807caDD27a656fC92Ff4E6733DFCbCb74D") {
            let balance = try! ec.getBalanceAt(ctx, account: testAddress, number: -1).getInt64()/10000000000
            store.perform(action: WalletChange.setBalance(UInt64(balance)))
            DispatchQueue.main.asyncAfter(deadline: .now() + 10.0, execute: {
                store.perform(action: WalletChange.setBalance(UInt64(balance)))
            })
        }
        print("latest block:\(try! ec.getBlockByNumber(ctx, number: -1).getNumber())")
    }

    func maxOutputAmount(toAddress: String) -> UInt64 {
        return balance
    }

    func createTx(forAmount: UInt64, toAddress: String) -> GethTransaction {
        let toAddr = GethAddress(fromHex: toAddress)
        return GethTransaction(1, to: toAddr, amount: GethBigInt(Int64(bitPattern: forAmount)), gasLimit: GethBigInt(0), gasPrice: GethBigInt(0), data: nil)
    }
    
    func signTx(_ tx: GethTransaction, ethPrivKey: String) -> GethTransaction {
        return tx
    }

    func publishTx(_ tx: GethTransaction) {
    }
}
