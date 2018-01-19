//
//  TokenWalletCoordinator.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-11-02.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation

class TokenWalletCoordinator {

    private let gethManager: GethManager
    private var timer: Timer? = nil
    private let apiClient: BRAPIClient

    init(gethManager: GethManager, apiClient: BRAPIClient) {
        self.gethManager = gethManager
        self.apiClient = apiClient
        Store.perform(action: WalletChange.set(Store.state.walletState.mutate(receiveAddress: gethManager.address.getHex())))
        self.refresh()
        self.timer = Timer.scheduledTimer(timeInterval: 3.0, target: self, selector: #selector(refresh), userInfo: nil, repeats: true)
    }

    @objc private func refresh() {
        guard let token = Store.state.walletState.token,
            let receiveAddress = Store.state.walletState.receiveAddress else { return }
        let tokenAddress = token.address

        apiClient.tokenBalance(tokenAddress: tokenAddress, address: Store.state.walletState.receiveAddress!, callback: { balance in
            DispatchQueue.main.async {
                Store.perform(action: WalletChange.set(Store.state.walletState.mutate(bigBalance: balance)))
            }
        })

        apiClient.tokenHistory(tokenAddress: tokenAddress, ethAddress: receiveAddress) { events in
            let newViewModels = events.sorted { $0.timeStamp > $1.timeStamp }.map {
                ERC20Transaction(event: $0, address: receiveAddress, token: token)
            }

            let oldViewModels = Store.state.walletState.transactions
            let oldCompleteViewModels = oldViewModels.filter { $0.status != .pending }
            let oldPendingViewModels = oldViewModels.filter { $0.status == .pending }

            let mergedViewModels: [Transaction]
            if oldPendingViewModels.count > 0 {
                if (oldPendingViewModels.count + oldCompleteViewModels.count) == newViewModels.count {
                    mergedViewModels = newViewModels
                } else {
                    mergedViewModels = oldPendingViewModels + newViewModels
                }
            } else {
                mergedViewModels = newViewModels
            }

            DispatchQueue.main.async {
                Store.perform(action: WalletChange.set(Store.state.walletState.mutate(transactions: mergedViewModels)))
            }
        }
    }
}
