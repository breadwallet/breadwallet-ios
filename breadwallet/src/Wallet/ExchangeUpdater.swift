//
//  ExchangeUpdater.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-01-27.
//  Copyright © 2017-2019 Breadwinner AG. All rights reserved.
//

import Foundation

class ExchangeUpdater: Subscriber {

    var lastUpdate = Date.distantPast
    let requestThrottleSeconds: TimeInterval = 5.0

    init() {
        Store.subscribe(self,
                        selector: { $0.defaultCurrencyCode != $1.defaultCurrencyCode },
                        callback: { state in
                            state.currencies.forEach { currency in
                                guard let currentRate = state[currency]!.rates.first( where: { $0.code == state.defaultCurrencyCode }) else { return }
                                Store.perform(action: WalletChange(currency).setExchangeRate(currentRate))
                            }
        })
    }

    func refresh(completion: @escaping () -> Void) {
        guard Date().timeIntervalSince(lastUpdate) > requestThrottleSeconds else { return }
        lastUpdate = Date()
        
        // get btc/fiat rates
        Backend.apiClient.exchangeRates(currencyCode: Currencies.btc.code) { [weak self] result in
            guard let `self` = self,
                let btc = Store.state.currencies.first(where: { $0.isBitcoin }),
                case .success(let btcFiatRates) = result else { return }
            
            Store.perform(action: WalletChange(btc).setExchangeRates(currentRate: self.findCurrentRate(in: btcFiatRates), rates: btcFiatRates))
            
            // get token/btc rates
            let tokens = Store.state.currencies.filter { !$0.isBitcoin }
            Backend.apiClient.tokenExchangeRates(tokens: tokens) { [weak self] result in
                guard let `self` = self,
                    case .success(let tokenBtcRates) = result else { return }

                // calculate token/fiat rates
                var tokenBtcDict = [String: Double]()
                tokenBtcRates.forEach { tokenBtcDict[$0.reciprocalCode] = $0.rate }
                let ethBtcRate = tokenBtcDict[Currencies.eth.code.lowercased()]
                tokens.forEach { currency in
                    var tokenBtcRate = tokenBtcDict[currency.code.lowercased()]
                    if tokenBtcRate == nil, let tokenEthRate = currency.defaultRate, let ethBtcRate = ethBtcRate {
                        tokenBtcRate = tokenEthRate * ethBtcRate
                    }
                    if let tokenBtcRate = tokenBtcRate {
                        let fiatRates: [Rate] = btcFiatRates.map { btcFiatRate in
                            let tokenFiatRate = btcFiatRate.rate * tokenBtcRate
                            return Rate(code: btcFiatRate.code, name: btcFiatRate.name, rate: tokenFiatRate, reciprocalCode: currency.code.lowercased())
                        }
                        Store.perform(action: WalletChange(currency).setExchangeRates(currentRate: self.findCurrentRate(in: fiatRates), rates: fiatRates))
                    } else {
                        print("ERROR: missing exchange rate for \(currency.code)")
                        assert(false, "missing exchange rate")
                    }
                }
            }
        }
    }

    private func findCurrentRate(in rates: [Rate]) -> Rate {
        guard let currentRate = rates.first( where: { $0.code == Store.state.defaultCurrencyCode }) else {
            Store.perform(action: DefaultCurrency.SetDefault(C.usdCurrencyCode))
            return rates.first( where: { $0.code == C.usdCurrencyCode })!
        }
        return currentRate
    }
}
