// 
//  GiftingStatusUpdater.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2020-11-21.
//  Copyright © 2020 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import Foundation
import WalletKit

class GiftingStatusUpdater {
    
    private let wallet: Wallet
    
    init(wallet: Wallet) {
        self.wallet = wallet
    }
    
    func monitor(txns: [Transaction], kvStore: BRReplicatedKVStore) {
        txns.forEach { self.monitor(txn: $0, kvStore: kvStore) }
    }
    
    private func monitor(txn: Transaction, kvStore: BRReplicatedKVStore) {
        guard let gift = txn.metaData?.gift else { return }
        
        //no need to check for claimed
        guard gift.claimed == false else { return }
        
        guard let key = Key.createFromString(asPrivate: gift.keyData) else { return }
        wallet.createSweeper(forKey: key) { result in
            switch result {
            case .success(let sweeper):
                print("[gifting]: created sweeper \(sweeper.balance.debugDescription)")
            case .failure(let error):
                switch error {
                case .insufficientFunds:
                    if txn.confirmations >= 6 {
                        let newGift = Gift(shared: true, claimed: true, txnHash: gift.txnHash, keyData: gift.keyData)
                        txn.updateGiftStatus(gift: newGift, kvStore: kvStore)
                        if let hash = newGift.txnHash {
                            Store.trigger(name: .txMetaDataUpdated(hash))
                        }
                        print("[gifting]: update gift status \(error)")
                    }
                default:
                    print("[gifting]: sweeper other error \(error)")
                }
            }
        }
    }
}
