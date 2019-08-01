//
//  WalletController.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2019-04-16.
//  Copyright © 2019 Breadwinner AG. All rights reserved.
//

import Foundation
import BRCrypto

/// Wrapper for BRCrypto Wallet
class Wallet {
    enum CreateTransferError: Error {
        case invalidAddress
        case invalidAmountOrFee
    }
    
    let core: BRCrypto.Wallet
    let currency: Currency
    private unowned let system: CoreSystem

    private var sendListener: SendListener?

//    var feeUnit: BRCrypto.Unit {
//        let currency = core.manager.network.currency
//        return core.manager.network.baseUnitFor(currency: currency)!
//    }

    /// The native network currency
    var networkCurrency: Currency? {
        return system.currency(forCoreCurrency: core.manager.network.currency)
    }
    
    var feeCurrency: Currency {
        return networkCurrency ?? currency
    }

    var balance: Amount {
        return Amount(cryptoAmount: core.balance, currency: currency)
    }

    var transfers: [Transaction] {
        return core.transfers
            .filter { $0.isVisible }
            .map { Transaction(transfer: $0,
                               wallet: self,
                               kvStore: Backend.kvStore,
                               rate: Store.state[currency]?.currentRate) }
            .sorted(by: { $0.timestamp > $1.timestamp })
    }

    /// Address to use as target for incoming transfers
    var receiveAddress: String {
        return core.target.description
    }
    
    func receiveAddress(for scheme: AddressScheme) -> String {
        return core.targetForScheme(scheme).description
    }

    func isOwnAddress(_ address: String) -> Bool {
        //TODO:CRYPTO need BRCrypto.Wallet interface -- this only works for single-address networks
        return core.target == Address.create(string: address, network: core.manager.network)
    }

    func createTransfer(to address: String, amount: Amount, feeBasis: TransferFeeBasis) -> Result<Transfer, CreateTransferError> {
        guard let target = Address.create(string: address, network: core.manager.network) else {
            return .failure(.invalidAddress)
        }
        guard let transfer = core.createTransfer(target: target, amount: amount.cryptoAmount, estimatedFeeBasis: feeBasis) else {
            return .failure(.invalidAmountOrFee)
        }
        return .success(transfer)
    }

    func submitTransfer(_ transfer: Transfer, seedPhrase: String) {
        core.manager.submit(transfer: transfer, paperKey: seedPhrase)
    }

    func subscribe(sendListener: SendListener) {
        assert(self.sendListener == nil)
        self.sendListener = sendListener
    }

    func unsubscribe(sendListener: SendListener) {
        guard let pendingTx = self.sendListener?.pendingTransfer, pendingTx.hash == sendListener.pendingTransfer.hash else { return assertionFailure() }
        self.sendListener = nil
    }

    init(core: BRCrypto.Wallet, currency: Currency, system: CoreSystem) {
        self.core = core
        self.currency = currency
        self.system = system
        
        //TODO:CRYPTO - this shouldn't be needed when balance is properly
        //set in sync ended
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            Store.perform(action: WalletChange(self.currency).setBalance(self.balance))
        }
    }
}

extension Wallet {
    func handleWalletEvent(_ event: WalletEvent) {
        //print("[SYS] \(currency.code) wallet event: \(event)")
        switch event {
            
        case .transferAdded(let transfer):
            break
        case .transferChanged(let transfer):
            break
        case .transferDeleted(let transfer):
            break
        case .transferSubmitted(let transfer, let success):
            guard let sendListener = sendListener, sendListener.pendingTransfer.hash == transfer.hash else { return assertionFailure() }
            sendListener.transferSubmitted(success: success)
            unsubscribe(sendListener: sendListener)

        case .balanceUpdated(let amount):
            DispatchQueue.main.async {
                Store.perform(action: WalletChange(self.currency).setBalance(Amount(cryptoAmount: amount, currency: self.currency)))
            }
        case .feeBasisUpdated:
            break

        case .created, .deleted, .changed:
            break
        }
    }

    func handleTransferEvent(_ event: TransferEvent, transfer: BRCrypto.Transfer) {
        //print("[SYS] \(currency.code) transfer \(transfer.hash?.description.truncateMiddle() ?? "") event: \(event)")
        //TODO:CRYPTO should use wallet transferSubmitted event but it never arrives
        if case .changed(let old, let new) = event,
            case .signed = old, case .submitted = new {
            guard let sendListener = sendListener, sendListener.pendingTransfer.hash == transfer.hash else { return assertionFailure() }
            sendListener.transferSubmitted(success: true) // must assume true?
            unsubscribe(sendListener: sendListener)
        }
    }
}

extension BRCrypto.Transfer {
    var isVisible: Bool {
        switch state {
        case .created, .signed, .deleted:
            return false
        default:
            return true
        }
    }
}
