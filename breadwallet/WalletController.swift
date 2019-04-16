//
//  WalletController.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2019-04-16.
//  Copyright © 2019 breadwallet LLC. All rights reserved.
//

import Foundation
import BRCrypto
import BRCore // UInt256

// TODO: name?
class WalletController {
    let wallet: Wallet
    let currency: Currency
    let manager: WalletManagerWrapper

    var kvStore: BRReplicatedKVStore? //TODO:CRYPTO temp hack

    var transfers: [Transaction] {
        return wallet.transfers.map { Transaction(transfer: $0, wallet: self) }.sorted(by: { $0.timestamp > $1.timestamp })
    }

    init(wallet: Wallet, currency: Currency, manager: WalletManagerWrapper) {
        self.wallet = wallet
        self.currency = currency
        self.manager = manager
    }
}

extension WalletController: WalletListener {
    func handleWalletEvent(system: System, manager: BRCrypto.WalletManager, wallet: Wallet, event: WalletEvent) {
        //print("[CRYPTO] \(wallet.currency.code) wallet event: \(event)")
        switch event {
            
        case .transferAdded(let transfer):
            break
        case .transferChanged(let transfer):
            break
        case .transferDeleted(let transfer):
            break
        case .balanceUpdated(let amount):
            DispatchQueue.main.async {
                Store.perform(action: WalletChange(self.currency).setBalance(Amount(coreAmount: amount, currency: self.currency)))
            }
        case .feeBasisUpdated:
            break

        case .created, .deleted, .changed:
            break
        }
    }
}

extension WalletController: TransferListener {
    func handleTransferEvent(system: System, manager: BRCrypto.WalletManager, wallet: Wallet, transfer: BRCrypto.Transfer, event: TransferEvent) {
        //print("[CRYPTO] \(wallet.currency.code) transfer \(transfer.hash?.description ?? "") event: \(event)")
        // this is redundant?
    }
}

//TODO:CRYPTO temp hack for backward compatibility
extension WalletController: WalletManager {

    var isConnected: Bool {
        return wallet.manager.state == .connected
    }

    func connect() {
        return
    }

    func disconnect() {
        return
    }

    func resetForWipe() {
        return
    }
}
