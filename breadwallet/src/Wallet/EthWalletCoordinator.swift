//
//  EthWalletCoordinator.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-10-24.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation

//Responsible for coordinating the state and
//gethManager
class EthWalletCoordinator {

    private let store: Store
    private let gethManager: GethManager

    init(store: Store, gethManager: GethManager) {
        self.store = store
        self.gethManager = gethManager
        store.perform(action: WalletChange.set(store.state.walletState.mutate(receiveAddress: gethManager.addr.getHex())))
    }
}
