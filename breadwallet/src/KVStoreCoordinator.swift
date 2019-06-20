//
//  KVStoreCoordinator.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-03-12.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation

class KVStoreCoordinator: Subscriber {

    init(kvStore: BRReplicatedKVStore) {
        self.kvStore = kvStore
        //TODO:CRYPTO availableTokens is not populated until later, after System creates all the wallets
        //setupStoredCurrencyList()
    }

    func setupStoredCurrencyList() {
        //If stored currency list metadata doesn't exist, create a new one
        guard let currencyMetaData = CurrencyListMetaData(kvStore: kvStore) else {
            let newCurrencyListMetaData = CurrencyListMetaData()
            newCurrencyListMetaData.enabledCurrencies = CurrencyListMetaData.defaultCurrencies
            set(newCurrencyListMetaData)
            setInitialDisplayWallets(metaData: newCurrencyListMetaData)
            return
        }

        if currencyMetaData.doesRequireSave == 1 {
            currencyMetaData.doesRequireSave = 0
            set(currencyMetaData)
            try? kvStore.syncKey(tokenListMetaDataKey, completionHandler: {_ in })
        }

        //TODO:CRYPTO availableTokens is not populated until later, after System creates all the wallets
        //assert(Store.state.availableTokens.count > 1, "missing token list")
        guard Store.state.availableTokens.count > 1 else { return }
        if currencyMetaData.enabledCurrencies.isEmpty {
            print("no wallets enabled in metadata, reverting to default")
            currencyMetaData.enabledCurrencies = CurrencyListMetaData.defaultCurrencies
            set(currencyMetaData)
        }
        self.setInitialDisplayWallets(metaData: currencyMetaData)

        Store.subscribe(self, name: .resetDisplayCurrencies, callback: { _ in
            self.resetDisplayCurrencies()
        })
    }

    private func resetDisplayCurrencies() {
        guard let currencyMetaData = CurrencyListMetaData(kvStore: kvStore) else {
            return setupStoredCurrencyList()
        }
        currencyMetaData.enabledCurrencies = CurrencyListMetaData.defaultCurrencies
        currencyMetaData.hiddenCurrencies = []
        set(currencyMetaData)
        try? kvStore.syncKey(tokenListMetaDataKey, completionHandler: {_ in })
        setInitialDisplayWallets(metaData: currencyMetaData)
    }

    //TODO:CRYPTO user token list / token address
    private func setInitialDisplayWallets(metaData: CurrencyListMetaData) {
        //skip this setup if stored wallets are the same as wallets in the state
        guard walletsHaveChanged(displayCurrencies: Store.state.displayCurrencies, enabledCurrencies: metaData.enabledCurrencies) else { return }

        let availableTokens = Store.state.availableTokens
        let oldWallets = Store.state.wallets
        var newWallets = [String: WalletState]()
        var displayOrder = 0
        var unknownTokensToRemove: [String] = []

        metaData.enabledCurrencies.forEach {
            if let walletState = oldWallets[$0] {
                newWallets[$0] = walletState.mutate(displayOrder: displayOrder)
                displayOrder += 1
            } else {
                //Since a WalletState wasn't found, it must be a token address
                let tokenAddress = $0.replacingOccurrences(of: C.erc20Prefix, with: "")
                //TODO:CRYPTO
//                if tokenAddress.lowercased() == Currencies.brd.address.lowercased() {
//                    newWallets[Currencies.brd.code] = oldWallets[Currencies.brd.code]!.mutate(displayOrder: displayOrder)
//                    displayOrder += 1
//                } else {
                    let filteredTokens = availableTokens.filter { $0.tokenAddress?.lowercased() == tokenAddress.lowercased() }
                    if let token = filteredTokens.first {
                        if let oldWallet = oldWallets[token.code] {
                            newWallets[token.code] = oldWallet.mutate(displayOrder: displayOrder)
                        } else {
                            newWallets[token.code] = WalletState.initial(token, displayOrder: displayOrder)
                        }
                        displayOrder += 1
                    } else {
                        unknownTokensToRemove.append($0)
                        print("unknown token \(tokenAddress) in metadata will be removed")
                    }
//                }
            }
        }
        
        //Remove any unknown tokens
        if !unknownTokensToRemove.isEmpty {
            metaData.enabledCurrencies = metaData.enabledCurrencies.filter { !unknownTokensToRemove.contains($0) }
            set(metaData)
            try? kvStore.syncKey(tokenListMetaDataKey, completionHandler: {_ in })
        }
        
        //Re-add hidden default currencies
        CurrencyListMetaData.defaultCurrencies.forEach {
            if let walletState = oldWallets[$0] {
                if newWallets[$0] == nil {
                    newWallets[$0] = walletState
                }
            }
            let tokenAddress = $0.replacingOccurrences(of: C.erc20Prefix, with: "")
            if tokenAddress.lowercased() == Currencies.brd.address.lowercased() {
                if newWallets[Currencies.brd.code] == nil {
                    newWallets[Currencies.brd.code] = oldWallets[Currencies.brd.code]
                }
            }
        }
        Store.perform(action: ManageWallets.SetWallets(newWallets))
    }

    private func walletsHaveChanged(displayCurrencies: [Currency], enabledCurrencies: [String]) -> Bool {
        let identifiers: [String] = displayCurrencies.map {
            if let tokenAddress = $0.tokenAddress {
                return C.erc20Prefix + tokenAddress
            } else {
                return $0.code
            }
        }
        return identifiers != enabledCurrencies
    }
    
    func retreiveStoredWalletInfo() {
        guard !hasRetreivedInitialWalletInfo else { return }
        //TODO:CRYPTO refactor, what's the purpose of wallet name / creation date in Store?
        if let walletInfo = WalletInfo(kvStore: kvStore) {
//            Store.perform(action: WalletChange(Currencies.btc).setWalletName(walletInfo.name))
//            Store.perform(action: WalletChange(Currencies.btc).setWalletCreationDate(walletInfo.creationDate))
        } else {
            print("no wallet info found")
        }
        hasRetreivedInitialWalletInfo = true
    }

    func listenForWalletChanges() {
        //TODO:CRYPTO wallet info
//        Store.subscribe(self,
//                        selector: { $0[Currencies.btc]?.creationDate != $1[Currencies.btc]?.creationDate },
//                            callback: {
//                                if let existingInfo = WalletInfo(kvStore: self.kvStore) {
//                                    Store.perform(action: WalletChange(Currencies.btc).setWalletCreationDate(existingInfo.creationDate))
//                                } else {
//                                    guard let btcState = $0[Currencies.btc] else { return }
//                                    let newInfo = WalletInfo(name: btcState.name)
//                                    newInfo.creationDate = btcState.creationDate
//                                    self.set(newInfo)
//                                }
//        })
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
