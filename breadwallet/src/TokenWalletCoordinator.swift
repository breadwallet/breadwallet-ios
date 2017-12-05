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
            let oldCompleteViewModels = oldViewModels.filter { $0.status != S.Transaction.pending }
            let oldPendingViewModels = oldViewModels.filter { $0.status == S.Transaction.pending }

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
                self.store.perform(action: WalletChange.set(self.store.state.walletState.mutate(transactions: mergedViewModels)))
            }
        }

        if let crowdsale = store.state.walletState.crowdsale {
            if crowdsale.startTime == nil || crowdsale.endTime == nil {
                if let start = gethManager.getStartTime(forContractAddress: crowdsale.contract.address), let end = gethManager.getEndTime(forContractAddress: crowdsale.contract.address) {
                    let newCrowdsale = Crowdsale(startTime: start, endTime: end, minContribution: crowdsale.minContribution, maxContribution: crowdsale.maxContribution, contract: crowdsale.contract)
                    store.perform(action: WalletChange.set(store.state.walletState.mutate(crowdSale: newCrowdsale)))
                }
            }

            if crowdsale.minContribution == nil || crowdsale.maxContribution == nil {
                if let minContribution = gethManager.getMinContribution(forContractAddress: crowdsale.contract.address), let maxContribution = gethManager.getMaxContribution(forContractAddress: crowdsale.contract.address) {
                    let newCrowdsale = Crowdsale(startTime: crowdsale.startTime, endTime: crowdsale.endTime, minContribution: minContribution, maxContribution: maxContribution, contract: crowdsale.contract)
                    store.perform(action: WalletChange.set(store.state.walletState.mutate(crowdSale: newCrowdsale)))
                }
            }
        }
    }

}
