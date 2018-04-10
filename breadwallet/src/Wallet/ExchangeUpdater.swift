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
        apiClient.exchangeRates(code: Currencies.btc.code) { [weak self] rates, error in
            guard let myself = self else { return }
            Store.perform(action: WalletChange(Currencies.btc).setExchangeRates(currentRate: myself.findCurrentRate(rates: rates), rates: rates))
            myself.apiClient.exchangeRates(code: Currencies.bch.code) { rates, error in
                Store.perform(action: WalletChange(Currencies.bch).setExchangeRates(currentRate: myself.findCurrentRate(rates: rates), rates: rates))
            }
            myself.apiClient.exchangeRates(code: Currencies.eth.code) {  rates, error in
                Store.perform(action: WalletChange(Currencies.eth).setExchangeRates(currentRate: myself.findCurrentRate(rates: rates), rates: rates))
                completion()
            }
        }
    }

    private func findCurrentRate(rates: [Rate]) -> Rate {
        guard let currentRate = rates.first( where: { $0.code == Store.state.defaultCurrencyCode }) else {
            Store.perform(action: DefaultCurrency.setDefault(C.usdCurrencyCode))
            return rates.first( where: { $0.code == C.usdCurrencyCode })!
        }
        return currentRate
    }

    //MARK: - Private
    let apiClient: BRAPIClient
}
