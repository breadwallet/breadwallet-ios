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
        guard let address = store.state.walletState.token?.address else { return }
        apiClient.tokenBalance(tokenAddress: address, address: store.state.walletState.receiveAddress!, callback: { balance in
            DispatchQueue.main.async {
                self.store.perform(action: WalletChange.set(self.store.state.walletState.mutate(bigBalance: balance)))
            }
        })
    }

}
