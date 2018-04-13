//
//  KVStoreCoordinator.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-03-12.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation

class KVStoreCoordinator : Subscriber {

    init(kvStore: BRReplicatedKVStore) {
        self.kvStore = kvStore
        setupStoredCurrencyList()
    }

    private func setupStoredCurrencyList() {
        //If stored currency list metadat doesn't exist, create a new one
        if CurrencyListMetaData(kvStore: kvStore) == nil {
            let newCurrencyListMetaData = CurrencyListMetaData()
            set(newCurrencyListMetaData)
        }
    }
    
    func retreiveStoredWalletInfo() {
        guard !hasRetreivedInitialWalletInfo else { return }
        if let walletInfo = WalletInfo(kvStore: kvStore) {
            //TODO:BCH
            Store.perform(action: WalletChange(Currencies.btc).setWalletName(walletInfo.name))
            Store.perform(action: WalletChange(Currencies.btc).setWalletCreationDate(walletInfo.creationDate))
        } else {
            print("no wallet info found")
        }
        hasRetreivedInitialWalletInfo = true
    }

    func listenForWalletChanges() {
        Store.subscribe(self,
                            selector: { $0[Currencies.btc].creationDate != $1[Currencies.btc].creationDate },
                            callback: {
                                if let existingInfo = WalletInfo(kvStore: self.kvStore) {
                                    Store.perform(action: WalletChange(Currencies.btc).setWalletCreationDate(existingInfo.creationDate))
                                } else {
                                    let newInfo = WalletInfo(name: $0[Currencies.btc].name)
                                    newInfo.creationDate = $0[Currencies.btc].creationDate
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

    private let kvStore: BRReplicatedKVStore
    private var hasRetreivedInitialWalletInfo = false
}
