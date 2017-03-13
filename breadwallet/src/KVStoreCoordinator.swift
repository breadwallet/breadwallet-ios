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

    func retreiveStoredWalletName() {
        guard !hasRetreivedInitialWalletName else { return }
        if let walletInfo = WalletInfo(kvStore: kvStore) {
            store.perform(action: WalletChange.setWalletName(walletInfo.name))
        }
        hasRetreivedInitialWalletName = true
    }

    func listenForWalletChanges() {
        store.lazySubscribe(self,
                            selector: { $0.walletState.name != $1.walletState.name },
                            callback: {
                                if let existingInfo = WalletInfo(kvStore: self.kvStore) {
                                    existingInfo.name = $0.walletState.name
                                    self.set(existingInfo)
                                } else {
                                    let newInfo = WalletInfo(name: $0.walletState.name)
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
    private var hasRetreivedInitialWalletName = false
}
