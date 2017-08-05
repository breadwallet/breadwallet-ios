//
//  WalletManager+BCash.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-08-04.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation
import BRCore

private let forkBlockHeight: UInt32 = 478559
private let minFeePerKb: UInt64 = ((1000*1000 + 190)/191)

class BadListener : BRWalletListener {
    func balanceChanged(_ balance: UInt64) {}
    func txAdded(_ tx: BRTxRef) {}
    func txUpdated(_ txHashes: [UInt256], blockHeight: UInt32, timestamp: UInt32) {}
    func txDeleted(_ txHash: UInt256, notifyUser: Bool, recommendRescan: Bool) {}
}

extension WalletManager {

    func sweepBCash(toAddress: String, callback: @escaping (String?) -> Void) {
        let genericError = "Something went wrong"
        guard let wallet = wallet else { return callback(genericError)}
        let txns = wallet.transactions.flatMap { return $0} .filter { $0.pointee.blockHeight < forkBlockHeight }
        guard let bCashWallet = BRWallet(transactions: txns, masterPubKey: self.masterPubKey, listener: BadListener()) else { return callback(genericError)}
        bCashWallet.feePerKb = minFeePerKb
        let maxOutputAmount = bCashWallet.maxOutputAmount
        guard let tx = bCashWallet.createTransaction(forAmount: maxOutputAmount, toAddress: toAddress) else { return callback(genericError)}
        defer { BRTransactionFree(tx) }
        var seed = UInt512()
        guard bCashWallet.signTransaction(tx, seed: &seed) else { return callback(genericError)}
        guard var bytes = tx.bytes else { return callback(genericError)}
        apiClient?.publishBCashTransaction(Data(bytes: &bytes, count: bytes.count), callback: callback)
    }

}
