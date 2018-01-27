//
//  EthWalletCoordinator.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-10-24.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation
import BRCore

//Responsible for coordinating the state and
//gethManager
class EthWalletCoordinator {

    private let gethManager: GethManager
    private let apiClient: BRAPIClient
    private var timer: Timer? = nil

    init(gethManager: GethManager, apiClient: BRAPIClient) {
        self.gethManager = gethManager
        self.apiClient = apiClient
        Store.perform(action: WalletChange(Currencies.eth).set(Currencies.eth.state.mutate(receiveAddress: gethManager.address.getHex())))
        self.refresh()
        self.timer = Timer.scheduledTimer(timeInterval: 3.0, target: self, selector: #selector(refresh), userInfo: nil, repeats: true)
    }

    @objc private func refresh() {
        apiClient.ethTxList(address: gethManager.address.getHex()) { transactions in
            let viewModels = transactions?.sorted { $0.timeStamp > $1.timeStamp }.map { EthTransaction(tx: $0, address: self.gethManager.address.getHex()) }
            guard let newViewModels = viewModels else { return }
            let oldViewModels = Currencies.eth.state.transactions

            let filteredOldViewModels = oldViewModels.filter { tx in
                if tx.status == .pending && !newViewModels.contains(where: { $0.hash == tx.hash }) {
                    return true
                } else {
                    return false
                }
            }
            let mergedViewModels: [Transaction] = filteredOldViewModels + newViewModels
            DispatchQueue.main.async {
                Store.perform(action: WalletChange(Currencies.eth).set(Currencies.eth.state.mutate(transactions: mergedViewModels)))
            }
        }
        Store.perform(action: WalletChange(Currencies.eth).set(Currencies.eth.state.mutate(bigBalance: gethManager.balance)))

        apiClient.ethExchangeRate { ethRate in
            if let ethBtcRate = Double(ethRate.ethbtc) {
                let ethRates = Currencies.eth.state.rates.map { btcRate in
                    return Rate(code: btcRate.code, name: btcRate.name, rate: btcRate.rate*ethBtcRate, reciprocalCode: "eth")
                }
                DispatchQueue.main.async {
                    guard let currentRate = ethRates.first( where: { $0.code == Store.state.defaultCurrencyCode }) else { return }
                    Store.perform(action: WalletChange(Currencies.eth).setExchangeRates(currentRate: currentRate, rates: ethRates))
                }
            }
        }
    }
}
