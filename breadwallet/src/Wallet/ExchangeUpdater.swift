//
//  ExchangeUpdater.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-01-27.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation

class ExchangeUpdater : Subscriber {

    let currency: CurrencyDef
    
    //MARK: - Public
    init(currency: CurrencyDef, walletManager: BTCWalletManager) {
        self.currency = currency
        self.walletManager = walletManager
        Store.subscribe(self,
                        selector: { $0.defaultCurrencyCode != $1.defaultCurrencyCode },
                        callback: { state in
                            guard let currentRate = state[self.currency].rates.first( where: { $0.code == state.defaultCurrencyCode }) else { return }
                            Store.perform(action: WalletChange(self.currency).setExchangeRate(currentRate))
        })
    }

    func refresh(completion: @escaping () -> Void) {
        walletManager.apiClient?.exchangeRates(code: currency.code) { rates, error in
            guard let currentRate = rates.first( where: { $0.code == Store.state.defaultCurrencyCode }) else { completion(); return }
            Store.perform(action: WalletChange(self.currency).setExchangeRates(currentRate: currentRate, rates: rates))
            completion()
        }
    }

    //MARK: - Private
    let walletManager: BTCWalletManager
}
