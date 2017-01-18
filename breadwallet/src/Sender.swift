//
//  Sender.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-01-16.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation

enum PublishResult {
    case success
    case failure(BRPeerManagerError)
}

class Sender {

    init(walletManager: WalletManager) {
        self.walletManager = walletManager
    }

    func send(amount: UInt64, to: String, verifyPin: (@escaping(String) -> Bool) -> Void, completion:@escaping (PublishResult) -> Void) {
        transaction = walletManager.wallet?.createTransaction(forAmount: amount, toAddress: to)
        guard let tx = transaction else { return }
        verifyPin({ pin in
            if self.walletManager.signTransaction(tx, pin: pin) {
                self.walletManager.peerManager?.publishTx(tx, completion: { success, error in
                    if let error = error {
                        completion(.failure(error))
                    } else {
                        completion(.success)
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
