//
//  TokenWalletCoordinator.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-11-02.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation

class TokenWalletCoordinator {

    private let currency: CurrencyDef = Currencies.brd
    private let gethManager: GethManager
    private var timer: Timer? = nil
    private let apiClient: BRAPIClient

    init(gethManager: GethManager, apiClient: BRAPIClient) {
        self.gethManager = gethManager
        self.apiClient = apiClient
        Store.perform(action: WalletChange(currency).set(currency.state.mutate(receiveAddress: gethManager.address.getHex())))
        self.refresh()
        self.timer = Timer.scheduledTimer(timeInterval: 3.0, target: self, selector: #selector(refresh), userInfo: nil, repeats: true)
    }

    @objc private func refresh() {
        guard let token = currency.state.token,
            let receiveAddress = currency.state.receiveAddress else { return }
        let tokenAddress = token.address

        apiClient.tokenBalance(tokenAddress: tokenAddress, address: self.currency.state.receiveAddress!, callback: { balance in
            DispatchQueue.main.async {
                Store.perform(action: WalletChange(self.currency).set(self.currency.state.mutate(bigBalance: balance)))
            }
        })

        apiClient.tokenHistory(tokenAddress: tokenAddress, ethAddress: receiveAddress) { events in
            let newViewModels = events.sorted { $0.timeStamp > $1.timeStamp }.map {
                ERC20Transaction(event: $0, address: receiveAddress, token: token)
            }

            let oldViewModels = self.currency.state.transactions
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
                Store.perform(action: WalletChange(self.currency).set(self.currency.state.mutate(transactions: mergedViewModels)))
            }
        }
    }
}
