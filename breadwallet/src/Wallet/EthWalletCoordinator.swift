//
//  EthWalletCoordinator.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-10-24.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation

//Responsible for coordinating the state and
//gethManager
class EthWalletCoordinator {

    private let store: Store
    private let gethManager: GethManager
    private let apiClient: BRAPIClient

    init(store: Store, gethManager: GethManager, apiClient: BRAPIClient) {
        self.store = store
        self.gethManager = gethManager
        self.apiClient = apiClient
        store.perform(action: WalletChange.set(store.state.walletState.mutate(receiveAddress: gethManager.addr.getHex())))

        apiClient.ethTxList(address: gethManager.addr.getHex()) { transactions in
            let viewModels = transactions?.map { EthTransaction(tx: $0, address: gethManager.addr.getHex()) }
            store.perform(action: WalletChange.set(store.state.walletState.mutate(transactions: viewModels)))
        }
        store.perform(action: WalletChange.set(store.state.walletState.mutate(balance: gethManager.balance)))

    }
}
