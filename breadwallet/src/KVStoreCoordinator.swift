//
//  KVStoreCoordinator.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-03-12.
//  Copyright © 2017-2019 Breadwinner AG. All rights reserved.
//

import Foundation

class KVStoreCoordinator: Subscriber {

    init(kvStore: BRReplicatedKVStore) {
        self.kvStore = kvStore
    }
    
    func retreiveStoredWalletInfo() {
        guard !hasRetreivedInitialWalletInfo else { return }
        if let walletInfo = WalletInfo(kvStore: kvStore) {
            Store.perform(action: AccountChange.SetName(walletInfo.name))
            Store.perform(action: AccountChange.SetCreationDate(walletInfo.creationDate))
        } else {
            print("no wallet info found")
        }
        hasRetreivedInitialWalletInfo = true
    }

    //TODO:CRYPTO when would this happen?
    func listenForWalletChanges() {
        Store.subscribe(self,
                        selector: { $0.creationDate != $1.creationDate },
                        callback: { state in
                            if let existingInfo = WalletInfo(kvStore: self.kvStore) {
                                Store.perform(action: AccountChange.SetCreationDate(existingInfo.creationDate))
                            } else {
                                let newInfo = WalletInfo(name: state.accountName)
                                newInfo.creationDate = state.creationDate
                                self.set(newInfo)
                            }
        })
    }

    private func set(_ info: BRKVStoreObject) {
        do {
            _ = try kvStore.set(info)
        } catch let error {
            print("error setting wallet info: \(error)")
        }
    }

    private let kvStore: BRReplicatedKVStore
    private var hasRetreivedInitialWalletInfo = false
}
