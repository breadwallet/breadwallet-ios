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

    //Amount in bits
    func send(amount: UInt64, to: String, verifyPin: (@escaping(String) -> Bool) -> Void, completion:@escaping (SendResult) -> Void) {
        let satoshis = amount * 100

        if let maxOutput = walletManager.wallet?.maxOutputAmount, satoshis > maxOutput {
            return completion(.creationError("Insufficient funds"))
        }

        transaction = walletManager.wallet?.createTransaction(forAmount: satoshis, toAddress: to)
        guard let tx = transaction else { return }
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
