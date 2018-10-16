//
//  KVStoreCoordinator.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-03-12.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation

class KVStoreCoordinator : Subscriber {

    init(store: Store, kvStore: BRReplicatedKVStore) {
        self.store = store
        self.kvStore = kvStore
    }

    func retreiveStoredWalletInfo() {
        guard !hasRetreivedInitialWalletInfo else { return }
        if let walletInfo = WalletInfo(kvStore: kvStore) {
            store.perform(action: WalletChange.setWalletName(walletInfo.name))
            store.perform(action: WalletChange.setWalletCreationDate(walletInfo.creationDate))
        } else {
            print("no wallet info found")
        }
        hasRetreivedInitialWalletInfo = true
    }

    func listenForWalletChanges() {
        store.subscribe(self,
                            selector: { $0.walletState.creationDate != $1.walletState.creationDate },
                            callback: {
                                if let existingInfo = WalletInfo(kvStore: self.kvStore) {
                                    self.store.perform(action: WalletChange.setWalletCreationDate(existingInfo.creationDate))
                                } else {
                                    let newInfo = WalletInfo(name: $0.walletState.name)
                                    newInfo.creationDate = $0.walletState.creationDate
                                    self.set(newInfo)
                                }
        })
    }

    private func set(_ info: BRKVStoreObject) {
        do {
            let _ = try kvStore.set(info)
        } catch let error {
            print("error setting wallet info: \(error)")
        }
    }

    private let store: Store
    private let kvStore: BRReplicatedKVStore
    private var hasRetreivedInitialWalletInfo = false
}
