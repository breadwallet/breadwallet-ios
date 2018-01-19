//
//  ExchangeUpdater.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-01-27.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation

class ExchangeUpdater : Subscriber {

    //MARK: - Public
    init(walletManager: WalletManager) {
        self.walletManager = walletManager
        Store.subscribe(self,
                        selector: { $0.defaultCurrencyCode != $1.defaultCurrencyCode },
                        callback: { state in
                            guard let currentRate = state.rates.first( where: { $0.code == state.defaultCurrencyCode }) else { return }
                            Store.perform(action: ExchangeRates.setRate(currentRate))
        })
    }

    func refresh(completion: @escaping () -> Void) {
        walletManager.apiClient?.exchangeRates { rates, error in
            guard let currentRate = rates.first( where: { $0.code == Store.state.defaultCurrencyCode }) else { completion(); return }
            Store.perform(action: ExchangeRates.setRates(currentRate: currentRate, rates: rates))
            completion()
        }
    }

    //MARK: - Private
    let walletManager: WalletManager
}
