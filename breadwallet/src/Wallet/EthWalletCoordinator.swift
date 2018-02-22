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
        Store.perform(action: WalletChange(Currencies.eth).set(Currencies.eth.state.mutate(bigBalance: gethManager.balance)))
    }
}
