//
//  WalletController.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2019-04-16.
//  Copyright © 2019 Breadwinner AG. All rights reserved.
//

import Foundation
import BRCrypto

typealias WalletEventCallback = (WalletEvent) -> Void

/// Wrapper for BRCrypto Wallet
class Wallet {
    enum CreateTransferError: Error {
        case invalidAddress
        case invalidAmountOrFee
    }
    
    let core: BRCrypto.Wallet
    let currency: Currency
    private unowned let system: CoreSystem

    // MARK: - Network

    /// The native network currency
    var networkCurrency: Currency? {
        return system.currency(forCoreCurrency: core.manager.network.currency)
    }

    var networkPrimaryWallet: Wallet? {
        guard let networkCurrency = networkCurrency else { return nil }
        return system.wallet(for: networkCurrency)
    }

    // MARK: - Fees

    var feeCurrency: Currency {
        return networkCurrency ?? currency
    }

    private var fees: [NetworkFee] {
        return core.manager.network.fees.sorted(by: { $0.timeIntervalInMilliseconds > $1.timeIntervalInMilliseconds})
    }
    
    private func feeForLevel(level: FeeLevel) -> NetworkFee {
        assert(fees.count == 3) //TODO:CRYPTO_V2 - support a dynamic number of fee tiers when supported by BlockchainDB
        return fees[level.rawValue]
    }
    
    public func estimateFee (address: String,
                             amount: Amount,
                             fee: FeeLevel,
                             completion: @escaping (TransferFeeBasis) -> Void) {
        guard let target = BRCrypto.Address.create(string: address, network: core.manager.network) else { return assertionFailure() }
        
        let networkFee: NetworkFee
        if fees.count == 1 {
            networkFee = fees.first!
        } else {
            networkFee = feeForLevel(level: fee)
        }
        core.estimateFee(target: target, amount: amount.cryptoAmount, fee: networkFee, completion: { result in
            guard case let .success(feeBasis) = result else { return }
            completion(feeBasis)
        })
    }

    // MARK: - State

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

    // MARK: Addresses

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

    // MARK: Sending

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

    // MARK: Event Subscriptions

    private var subscriptions: [Int: [WalletEventCallback]] = [:]

    func subscribe(_ subscriber: Subscriber, callback: @escaping WalletEventCallback) {
        subscriptions[subscriber.hashValue, default: []].append(callback)
    }

    func unsubscribe(_ subscriber: Subscriber) {
        subscriptions.removeValue(forKey: subscriber.hashValue)
    }

    private func publishEvent(_ event: WalletEvent) {
        subscriptions
            .flatMap { $0.value }
            .forEach { $0(event) }
    }

    // MARK: Init

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

// MARK: - Events

extension Wallet {
    func handleWalletEvent(_ event: WalletEvent) {
        //print("[SYS] \(currency.code) wallet event: \(event)")
        switch event {
            
        case .transferAdded:
            break
        case .transferChanged:
            break
        case .transferDeleted:
            break
        case .transferSubmitted:
            assertionFailure("this is working now, remove the hack in handleTransferEvent")
            break

        case .balanceUpdated(let amount):
            DispatchQueue.main.async {
                Store.perform(action: WalletChange(self.currency).setBalance(Amount(cryptoAmount: amount, currency: self.currency)))
            }
        case .feeBasisUpdated, .feeBasisEstimated:
            break

        case .created, .deleted, .changed:
            break
        }

        publishEvent(event)
    }

    func handleTransferEvent(_ event: TransferEvent, transfer: BRCrypto.Transfer) {
        //print("[SYS] \(currency.code) transfer \(transfer.hash?.description.truncateMiddle() ?? "") event: \(event)")
        if case .changed(_, let new) = event, case .submitted = new {
            //TODO:CRYPTO workaround needed because transferSubmitted is never received
            publishEvent(.transferSubmitted(transfer: transfer, success: true))
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
