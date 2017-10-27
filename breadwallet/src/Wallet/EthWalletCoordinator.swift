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
    private var timer: Timer? = nil

    init(store: Store, gethManager: GethManager, apiClient: BRAPIClient) {
        self.store = store
        self.gethManager = gethManager
        self.apiClient = apiClient
        store.perform(action: WalletChange.set(store.state.walletState.mutate(receiveAddress: gethManager.addr.getHex())))
        self.refresh()
        self.timer = Timer.scheduledTimer(timeInterval: 3.0, target: self, selector: #selector(refresh), userInfo: nil, repeats: true)
    }

    @objc private func refresh() {
        apiClient.ethTxList(address: gethManager.addr.getHex()) { transactions in
            let viewModels = transactions?.sorted { $0.timeStamp > $1.timeStamp }.map { EthTransaction(tx: $0, address: self.gethManager.addr.getHex(), store: self.store) }
            self.store.perform(action: WalletChange.set(self.store.state.walletState.mutate(transactions: viewModels)))
        }
        store.perform(action: WalletChange.set(store.state.walletState.mutate(balance: gethManager.balance)))
    }
}
