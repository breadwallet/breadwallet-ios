//
//  ExchangeUpdater.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-01-27.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation

class ExchangeUpdater : Subscriber {

    let currencies: [CurrencyDef]
    
    //MARK: - Public
    init(currencies: [CurrencyDef], apiClient: BRAPIClient) {
        self.currencies = currencies
        self.apiClient = apiClient
        currencies.forEach { currency in
            Store.subscribe(self,
                            selector: { $0.defaultCurrencyCode != $1.defaultCurrencyCode },
                            callback: { state in
                                guard let currentRate = state[currency].rates.first( where: { $0.code == state.defaultCurrencyCode }) else { return }
                                Store.perform(action: WalletChange(currency).setExchangeRate(currentRate))
            })
        }
    }

    func refresh(completion: @escaping () -> Void) {
        let dispatchGroup = DispatchGroup()
        currencies.forEach { currency in
            dispatchGroup.enter()
            apiClient.exchangeRates(code: currency.code) { rates, error in
                guard let currentRate = rates.first( where: { $0.code == Store.state.defaultCurrencyCode }) else { completion(); return }
                Store.perform(action: WalletChange(currency).setExchangeRates(currentRate: currentRate, rates: rates))
                dispatchGroup.leave()
            }
        }
        dispatchGroup.notify(queue: .main) {
            completion()
        }
    }

    //MARK: - Private
    let apiClient: BRAPIClient
}
