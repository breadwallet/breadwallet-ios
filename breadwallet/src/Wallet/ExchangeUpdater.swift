//
//  ExchangeUpdater.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-01-27.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation

class ExchangeUpdater {

    //MARK: - Public
    init(store: Store, apiClient: BRAPIClient) {
        self.store = store
        self.apiClient = apiClient
    }

    func refresh() {
        apiClient.exchangeRates { rates, error in
            guard let currencyCode = Locale.current.currencyCode else { return }
            guard let currentRate = rates.first( where: { $0.code == currencyCode }) else { return }
            self.store.perform(action: ExchangeRates.setRate(currentRate))
        }
    }

    //MARK: - Private
    let store: Store
    let apiClient: BRAPIClient
}
