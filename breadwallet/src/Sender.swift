//
//  Sender.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-01-16.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation

enum SendResult {
    case success
    case creationError(String)
    case publishFailure(BRPeerManagerError)
}

class Sender {

    init(walletManager: WalletManager) {
        self.walletManager = walletManager
    }

    func createTransaction(amount: UInt64, to: String) {
        transaction = walletManager.wallet?.createTransaction(forAmount: amount, toAddress: to)
    }

    var fee: UInt64 {
        guard let tx = transaction else { return 0 }
        return walletManager.wallet?.feeForTx(tx) ?? 0
    }

    func feeForTx(amount: UInt64) -> UInt64 {
        return walletManager.wallet?.feeForTx(amount:amount) ?? 0
    }

    //Amount in bits
    func send(verifyPin: (@escaping(String) -> Bool) -> Void, completion:@escaping (SendResult) -> Void) {
        guard let tx = transaction else { return completion(.creationError("Transaction not created")) }
        verifyPin({ pin in
            if self.walletManager.signTransaction(tx, pin: pin) {
                self.walletManager.peerManager?.publishTx(tx, completion: { success, error in
                    DispatchQueue.main.async {
                        if let error = error {
                            completion(.publishFailure(error))
                        } else {
                            completion(.success)
                        }
                    }
                })
                return true
            } else {
                return false
            }
        })
    }

    private let walletManager: WalletManager
    private var transaction: BRTxRef?
}
