//
//  EthWalletCoordinator.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-10-24.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation
import Geth
import BRCore

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
        store.perform(action: WalletChange.set(store.state.walletState.mutate(receiveAddress: gethManager.address.getHex())))
        self.refresh()
        self.timer = Timer.scheduledTimer(timeInterval: 3.0, target: self, selector: #selector(refresh), userInfo: nil, repeats: true)
    }

    @objc private func refresh() {
        apiClient.ethTxList(address: gethManager.address.getHex()) { transactions in
            let viewModels = transactions?.sorted { $0.timeStamp > $1.timeStamp }.map { EthTransaction(tx: $0, address: self.gethManager.address.getHex(), store: self.store) }
            guard let newViewModels = viewModels else { return }
            let oldViewModels = self.store.state.walletState.transactions

            let filteredOldViewModels = oldViewModels.filter { tx in
                if tx.status == "Pending" && !newViewModels.contains(where: { $0.hash == tx.hash }) {
                    return true
                } else {
                    return false
                }
            }
            let mergedViewModels: [Transaction] = filteredOldViewModels + newViewModels
            DispatchQueue.main.async {
                self.store.perform(action: WalletChange.set(self.store.state.walletState.mutate(transactions: mergedViewModels)))
            }
        }
        store.perform(action: WalletChange.set(store.state.walletState.mutate(bigBalance: gethManager.balance)))
    }
}
