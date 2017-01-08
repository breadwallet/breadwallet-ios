//
//  WalletCreator.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-12-30.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import Foundation

class WalletCreator : Subscriber {
    private let walletManager: WalletManager
    private let store: Store

    init(walletManager: WalletManager, store: Store) {
        self.walletManager = walletManager
        self.store = store
        addStoreSubscriptions()
    }

    private func addStoreSubscriptions() {
        store.subscribe(self,
                        selector: { $0.pinCreationStep != $1.pinCreationStep },
                        callback: { self.setPinForState($0) })
    }

    private func setPinForState(_ state: State) {
        if case .save(let pin) = state.pinCreationStep {
            if let phrase = self.walletManager.setRandomSeedPhrase() {
                if walletManager.forceSetPin(newPin: pin, seedPhrase: phrase) {
                    //TODO move SaveSuccess() here once setting the pin works
                    print("Set Pin Success")
                }
                DispatchQueue(label: "com.breadwallet.BRCore").async {
                    self.walletManager.peerManager?.connect()
                }
            }
            store.perform(action: PinCreation.SaveSuccess())
        }
    }
}
