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
//private let minFeePerKb: UInt64 = ((1000ULL*1000 + 190)/191)
private let minFeePerKb: UInt64 = ((1000*1000 + 190)/191)
class BadListener : BRWalletListener {
    func balanceChanged(_ balance: UInt64) {}
    func txAdded(_ tx: BRTxRef) {}
    func txUpdated(_ txHashes: [UInt256], blockHeight: UInt32, timestamp: UInt32) {}
    func txDeleted(_ txHash: UInt256, notifyUser: Bool, recommendRescan: Bool) {}
}

extension WalletManager {

    func sweepBCash(toAddress: String) {

        guard let wallet = wallet else { return }
        let txns = wallet.transactions.flatMap { return $0} .filter { $0.pointee.blockHeight < forkBlockHeight }

        if let bCashWallet = BRWallet(transactions: txns, masterPubKey: self.masterPubKey, listener: BadListener()) {
            bCashWallet.feePerKb = minFeePerKb

            let maxOutputAmount = bCashWallet.maxOutputAmount

            if let tx = bCashWallet.createTransaction(forAmount: maxOutputAmount, toAddress: toAddress) {

                var seed = UInt512()
                let _ = bCashWallet.signTransaction(tx, seed: &seed)

                let txBytes = tx.bytes
                print("bytes: \(String(describing: txBytes))")
                //Send to api endpoint


                BRTransactionFree(tx)
                //BRWalletFree(bCashWallet)
            }

        }

    }

}
