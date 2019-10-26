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
typealias CreateTransferResult = Result<Transfer, Wallet.CreateTransferError>

extension NetworkFee {
    var time: Int { return Int(timeIntervalInMilliseconds) }
}

/// Wrapper for BRCrypto Wallet
class Wallet {
    enum CreateTransferError: Error {
        case invalidAddress
        case invalidAmountOrFee
    }
    
    let currency: Currency
    private let core: BRCrypto.Wallet
    private unowned let system: CoreSystem

    // MARK: - Network
    
    var manager: WalletManager {
        return core.manager
    }

    /// The native network currency
    var networkCurrency: Currency? {
        return system.currencies[core.manager.network.currency.uid]
    }

    var networkPrimaryWallet: Wallet? {
        return system.wallets[core.manager.network.currency.uid]
    }
    
    var connectionMode: WalletConnectionMode {
        return system.connectionMode(for: currency)
    }

    // MARK: - Fees

    var feeCurrency: Currency {
        return networkCurrency ?? currency
    }

    private var fees: [NetworkFee] {
        return core.manager.network.fees.sorted(by: { $0.timeIntervalInMilliseconds > $1.timeIntervalInMilliseconds})
    }
    
    func feeForLevel(level: FeeLevel) -> NetworkFee {
        //Find nearest NetworkFee for FeeLevel
        let target = level.preferredTime(forCurrency: currency)
        guard let result = fees.enumerated().min(by: { abs($0.1.time - target) < abs($1.1.time - target) }) else {
            return fees.first!
        }
        return result.element
    }
    
    public func estimateFee (address: String,
                             amount: Amount,
                             fee: FeeLevel,
                             completion: @escaping (TransferFeeBasis?) -> Void) {
        guard let target = BRCrypto.Address.create(string: address, network: core.manager.network) else { return assertionFailure() }
        
        let networkFee: NetworkFee
        if fees.count == 1 {
            networkFee = fees.first!
        } else {
            networkFee = feeForLevel(level: fee)
        }
        core.estimateFee(target: target, amount: amount.cryptoAmount, fee: networkFee, completion: { result in
            guard case let .success(feeBasis) = result else {
                completion(nil)
                return
            }
            completion(feeBasis)
        })
    }
    
    func updateNetworkFees() {
        system.updateFees()
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
        return core.target.sanitizedDescription
    }
    
    func receiveAddress(for scheme: AddressScheme) -> String {
        return core.targetForScheme(scheme).sanitizedDescription
    }

    func isOwnAddress(_ address: String) -> Bool {
        //TODO:CRYPTO need BRCrypto.Wallet interface -- this only works for single-address networks
        return core.target == Address.create(string: address, network: core.manager.network)
    }

    // MARK: Sending

    func createTransfer(to address: String, amount: Amount, feeBasis: TransferFeeBasis) -> CreateTransferResult {
        guard let target = Address.create(string: address, network: core.manager.network) else {
            return .failure(.invalidAddress)
        }
        guard let transfer = core.createTransfer(target: target, amount: amount.cryptoAmount, estimatedFeeBasis: feeBasis) else {
            return .failure(.invalidAmountOrFee)
        }
        return .success(transfer)
    }
    
    func createTransfer(forProtocolRequest protoReq: PaymentProtocolRequest, feeBasis: TransferFeeBasis) -> CreateTransferResult {
        guard protoReq.primaryTarget != nil else {
            return .failure(.invalidAddress)
        }
        guard let transfer = protoReq.createTransfer(estimatedFeeBasis: feeBasis) else {
            return .failure(.invalidAmountOrFee)
        }
        return .success(transfer)
    }

    func submitTransfer(_ transfer: Transfer, seedPhrase: String) {
        core.manager.submit(transfer: transfer, paperKey: seedPhrase)
    }
    
    func createSweeper(forKey key: Key, completion: @escaping (Result<WalletSweeper, WalletSweeperError>) -> Void ) {
        core.manager.createSweeper(wallet: core, key: key, completion: completion)
    }
    
    func createPaymentProtocolRequest(forBip70 data: Data) -> PaymentProtocolRequest? {
        return PaymentProtocolRequest.create(wallet: core, forBip70: data)
    }
    
    func createPaymentProtocolRequest(forBitPay jsonData: Data) -> PaymentProtocolRequest? {
        return PaymentProtocolRequest.create(wallet: core, forBitPay: jsonData)
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
        switch event {
        case .created:
            publishEvent(.transferAdded(transfer: transfer))
        case .changed(_, let new):
            //TODO:CRYPTO workaround needed because transferSubmitted is never received
            switch new {
            case .submitted:
                publishEvent(.transferSubmitted(transfer: transfer, success: true))
            case .created:
                publishEvent(.transferAdded(transfer: transfer))
            case .deleted:
                publishEvent(.transferDeleted(transfer: transfer))
            default:
                publishEvent(.transferChanged(transfer: transfer))
            }
        case .deleted:
            publishEvent(.transferDeleted(transfer: transfer))
        }
        if case .changed(_, let new) = event, case .failed(_) = new {
            //TODO:CRYPTO workaround needed because transferSubmitted is never received
            publishEvent(.transferSubmitted(transfer: transfer, success: false))
        }
    }
}

extension BRCrypto.Transfer {
    var isVisible: Bool {
        switch state {
        case .deleted:
            return false
        case .created, .signed: // skip un-submitted outgoing transactions
            return direction != .sent
        default:
            return true
        }
    }
}
