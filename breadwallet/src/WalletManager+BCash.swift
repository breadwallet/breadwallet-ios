//
//  WalletManager+BCash.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-08-04.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation
import BRCore

let bCashForkBlockHeight: UInt32 = E.isTestnet ? 1155744 : 478559 //Testnet is just a guess
private let minFeePerKb: UInt64 = ((1000*1000 + 190)/191)

class BadListener : BRWalletListener {
    func balanceChanged(_ balance: UInt64) {}
    func txAdded(_ tx: BRTxRef) {}
    func txUpdated(_ txHashes: [UInt256], blockHeight: UInt32, timestamp: UInt32) {}
    func txDeleted(_ txHash: UInt256, notifyUser: Bool, recommendRescan: Bool) {}
}

extension WalletManager {

    var bCashBalance: UInt64 {
        return bCashWallet?.maxOutputAmount ?? 0
    }

    func sweepBCash(toAddress: String, callback: @escaping (String?) -> Void) {
        let genericError = "Something went wrong"
        guard let bCashWallet = bCashWallet else { return callback(genericError) }
        bCashWallet.feePerKb = minFeePerKb
        let maxOutputAmount = bCashWallet.maxOutputAmount
        guard let tx = bCashWallet.createTransaction(forAmount: maxOutputAmount, toAddress: toAddress) else { return callback(genericError)}
        defer { BRTransactionFree(tx) }
        var seed = UInt512()
        guard bCashWallet.signTransaction(tx, seed: &seed) else { return callback(genericError)}
        guard var bytes = tx.bytes else { return callback(genericError)}
        apiClient?.publishBCashTransaction(Data(bytes: &bytes, count: bytes.count), callback: { errorMessage in
            if errorMessage == nil {
                UserDefaults.standard.set(tx.txHash.description, forKey: "bCashTxHashKey")
            }
            callback(errorMessage)
        })
    }

}
