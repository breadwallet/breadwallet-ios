//
//  ExchangeUpdater.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-01-27.
//  Copyright © 2017-2019 Breadwinner AG. All rights reserved.
//

import Foundation

class ExchangeUpdater: Subscriber {

    private var lastUpdate = Date.distantPast
    private let requestThrottleSeconds: TimeInterval = 5.0
    
    // MARK: - Public

    init() {
        Store.lazySubscribe(self,
                        selector: { $0.defaultCurrencyCode != $1.defaultCurrencyCode },
                        callback: { _ in
                            self.forceRefresh()
                        })
    }
    
    func refresh() {
        guard Date().timeIntervalSince(lastUpdate) > requestThrottleSeconds else { return }
        self.forceRefresh()
    }

    private func forceRefresh() {
        guard !Store.state.currencies.isEmpty else { return }
        
        lastUpdate = Date()
        
        Backend.apiClient.fetchPriceInfo(currencies: Store.state.currencies) { result in
            guard case .success(let priceInfo) = result else { return }
            Store.state.currencies.forEach {
                guard let info = priceInfo[$0.code.uppercased()] else { return }
                
                Store.perform(action: WalletChange($0).setFiatPriceInfo(info))
                
                let fiatCode = Store.state.defaultCurrencyCode
                let rate = Rate(code: fiatCode, name: $0.name, rate: info.price, reciprocalCode: $0.code)
                Store.perform(action: WalletChange($0).setExchangeRate(rate))
            }
        }
    }

}
