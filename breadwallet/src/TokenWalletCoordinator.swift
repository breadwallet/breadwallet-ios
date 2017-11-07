//
//  TokenWalletCoordinator.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-11-02.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation

class TokenWalletCoordinator {

    private let store: Store
    private let gethManager: GethManager
    private var timer: Timer? = nil
    private let apiClient: BRAPIClient

    init(store: Store, gethManager: GethManager, apiClient: BRAPIClient) {
        self.store = store
        self.gethManager = gethManager
        self.apiClient = apiClient
        store.perform(action: WalletChange.set(store.state.walletState.mutate(receiveAddress: gethManager.address.getHex())))
        self.refresh()
        self.timer = Timer.scheduledTimer(timeInterval: 3.0, target: self, selector: #selector(refresh), userInfo: nil, repeats: true)
    }

    @objc private func refresh() {
        guard let tokenAddress = store.state.walletState.token?.address else { return }
        guard let receiveAddress = store.state.walletState.receiveAddress else { return }

        apiClient.tokenBalance(tokenAddress: tokenAddress, address: store.state.walletState.receiveAddress!, callback: { balance in
            DispatchQueue.main.async {
                self.store.perform(action: WalletChange.set(self.store.state.walletState.mutate(bigBalance: balance)))
            }
        })

        apiClient.tokenHistory(tokenAddress: tokenAddress, ethAddress: receiveAddress) { events in
            let newViewModels = events.sorted { $0.timeStamp > $1.timeStamp }.map {
                TokenTransaction(event: $0, address: receiveAddress, store: self.store)
            }

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
    }

}
