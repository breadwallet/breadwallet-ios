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
        //If stored currency list metadata doesn't exist, create a new one
        guard let currencyMetaData = CurrencyListMetaData(kvStore: kvStore) else {
            let newCurrencyListMetaData = CurrencyListMetaData()
            set(newCurrencyListMetaData)
            return
        }
        let enabledTokenAddresses = currencyMetaData.enabledTokenAddresses
        StoredTokenData.fetchTokens(callback: { tokenData in
            var currentWalletCount = Store.state.wallets.values.count
            let enabledTokenData = tokenData.filter { enabledTokenAddresses.contains($0.address) }
            let enabledCurrencies = enabledTokenData.map { ERC20Token(tokenData: $0)}.reduce([String: WalletState]()) { (dictionary, currency) -> [String: WalletState] in
                var dictionary = dictionary
                dictionary[currency.code] = WalletState.initial(currency, displayOrder: currentWalletCount)
                currentWalletCount = currentWalletCount + 1
                return dictionary
            }
            Store.perform(action: ManageWallets.addWallets(enabledCurrencies))
        })
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
                        selector: { $0[Currencies.btc]?.creationDate != $1[Currencies.btc]?.creationDate },
                            callback: {
                                if let existingInfo = WalletInfo(kvStore: self.kvStore) {
                                    Store.perform(action: WalletChange(Currencies.btc).setWalletCreationDate(existingInfo.creationDate))
                                } else {
                                    guard let btcState = $0[Currencies.btc] else { return }
                                    let newInfo = WalletInfo(name: btcState.name)
                                    newInfo.creationDate = btcState.creationDate
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
