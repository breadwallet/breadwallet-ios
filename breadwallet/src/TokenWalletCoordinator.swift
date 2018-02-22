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
    }
}
