//
//  Sender.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-01-16.
//  Copyright © 2017-2019 Breadwinner AG. All rights reserved.
//

import Foundation
import UIKit
import WalletKit

enum SendResult {
    case success(hash: String?, rawTx: String?)
    case creationError(message: String)
    case publishFailure(code: Int, message: String)
    case insufficientGas(message: String)
}

enum SenderValidationResult {
    case ok
    case failed
    case invalidAddress
    case ownAddress
    case insufficientFunds
    case noExchangeRate
    
    // BTC errors
    case noFees // fees not downlaoded
    case outputTooSmall(Amount)
    
    // protocol request errors
    case invalidRequest(String)
    case paymentTooSmall(Amount)
    case usedAddress
    case identityNotCertified(String)
    
    // token errors
    case insufficientGas // no eth for token transfer gas
}

typealias PinVerifier = (@escaping (String) -> Void) -> Void
typealias SendCompletion = (SendResult) -> Void

class Sender: Subscriber {
    
    let wallet: Wallet
    private let kvStore: BRReplicatedKVStore
    private let authenticator: TransactionAuthenticator
    
    private var comment: String?
    private var gift: Gift?
    private var transfer: WalletKit.Transfer?
    private var protocolRequest: PaymentProtocolRequest?
    var maximum: Amount?
    var minimum: Amount?
    
    var displayPaymentProtocolResponse: ((String) -> Void)?
    
    private var submitTimeoutTimer: Timer? {
        willSet {
            submitTimeoutTimer?.invalidate()
        }
    }
    private let submitTimeout: TimeInterval = 10.0

    private var isOriginatingTransferNeeded: Bool {
        return wallet.currency.tokenType == .erc20
    }

    var canUseBiometrics: Bool {
        return authenticator.isBiometricsEnabledForTransactions
    }

    // MARK: Init

    init(wallet: Wallet, authenticator: TransactionAuthenticator, kvStore: BRReplicatedKVStore) {
        self.wallet = wallet
        self.authenticator = authenticator
        self.kvStore = kvStore
    }

    func reset() {
        transfer = nil
        comment = nil
        protocolRequest = nil
    }
    
    func updateNetworkFees() {
        wallet.updateNetworkFees()
    }

    // MARK: Create

    func estimateFee(address: String, amount: Amount, tier: FeeLevel, completion: @escaping (TransferFeeBasis?) -> Void) {
        wallet.estimateFee(address: address, amount: amount, fee: tier, completion: completion)
    }
    
    public func estimateLimitMaximum (address: String,
                                      fee: FeeLevel,
                                      completion: @escaping WalletKit.Wallet.EstimateLimitHandler) {
        wallet.estimateLimitMaximum(address: address, fee: fee, completion: completion)
    }
    
    public func estimateLimitMinimum (address: String,
                                      fee: FeeLevel,
                                      completion: @escaping WalletKit.Wallet.EstimateLimitHandler) {
        wallet.estimateLimitMinimum(address: address, fee: fee, completion: completion)
    }

    private func validate(address: String, amount: Amount, feeBasis: TransferFeeBasis? = nil) -> SenderValidationResult {
        guard wallet.currency.isValidAddress(address) else { return .invalidAddress }
        guard !wallet.isOwnAddress(address) else { return .ownAddress }

        if let minOutput = minimum {
            guard amount >= minOutput else { return .outputTooSmall(minOutput) }
        }

        if let maximum = maximum {
            guard amount <= maximum else { return .insufficientFunds }
        } else if let balance = wallet.currency.state?.balance {
            guard amount <= balance else { return .insufficientFunds }
        }
        if wallet.feeCurrency != wallet.currency {
            if let feeBalance = wallet.feeCurrency.state?.balance, let feeBasis = feeBasis {
                let feeAmount = Amount(cryptoAmount: feeBasis.fee, currency: wallet.feeCurrency)
                if feeBalance.tokenValue < feeAmount.tokenValue {
                    return .insufficientGas
                }
            }
        }
        return .ok
    }

    func createTransaction(address: String,
                           amount: Amount,
                           feeBasis: TransferFeeBasis,
                           comment: String?,
                           attribute: String? = nil,
                           gift: Gift? = nil) -> SenderValidationResult {
        assert(transfer == nil)
        let result = validate(address: address, amount: amount, feeBasis: feeBasis)
        guard case .ok = result else { return result }
        switch wallet.createTransfer(to: address, amount: amount, feeBasis: feeBasis, attribute: attribute) {
        case .success(let transfer):
            self.comment = comment
            self.gift = gift
            self.transfer = transfer
            return .ok
        case .failure(let error) where error == .invalidAddress:
            return .invalidAddress
        default:
            return .failed
        }
    }

    // MARK: Create Payment Request
    private func validate(protocolRequest protoReq: PaymentProtocolRequest, ignoreUsedAddress: Bool, ignoreIdentityNotCertified: Bool) -> SenderValidationResult {
        if !protoReq.isSecure && !ignoreIdentityNotCertified {
            return .identityNotCertified("")
        }
        guard let address = protoReq.primaryTarget?.description else {
            return .invalidAddress
        }
        guard let amount = protoReq.totalAmount else {
            return .invalidRequest("No Amount Specified")
        }
        return validate(address: address, amount: Amount(cryptoAmount: amount, currency: wallet.currency), feeBasis: nil)
    }

    func createTransaction(protocolRequest protoReq: PaymentProtocolRequest,
                           ignoreUsedAddress: Bool,
                           ignoreIdentityNotCertified: Bool,
                           feeBasis: TransferFeeBasis,
                           comment: String?) -> SenderValidationResult {
        assert(transfer == nil)
        let result = validate(protocolRequest: protoReq, ignoreUsedAddress: ignoreUsedAddress, ignoreIdentityNotCertified: ignoreIdentityNotCertified)
        guard case .ok = result else { return result }
        switch wallet.createTransfer(forProtocolRequest: protoReq, feeBasis: feeBasis) {
        case .success(let transfer):
            self.comment = comment
            self.transfer = transfer
            self.protocolRequest = protoReq
            return .ok
        case .failure(let error) where error == .invalidAddress:
            return .invalidAddress
        default:
            return .failed
        }
    }

    // MARK: Submit

    func sendTransaction(allowBiometrics: Bool, pinVerifier: @escaping PinVerifier, completion: @escaping SendCompletion) {
        guard let transfer = transfer else { return completion(.creationError(message: "no tx")) }
        if allowBiometrics && canUseBiometrics {
            sendWithBiometricVerification(transfer: transfer, completion: completion)
        } else {
            sendWithPinVerification(transfer: transfer, pinVerifier: pinVerifier, completion: completion)
        }
    }
    
    private func sendWithPinVerification(transfer: Transfer,
                                         pinVerifier: PinVerifier,
                                         completion: @escaping SendCompletion) {
        // this block requires a strong reference to self to ensure the Sender is not deallocated before completion
        pinVerifier { pin in
            guard self.authenticator.signAndSubmit(transfer: transfer, wallet: self.wallet, withPin: pin) else {
                return completion(.creationError(message: S.Send.Error.authenticationError))
            }
            self.waitForSubmission(of: transfer, completion: completion)
        }
    }
    
    private func sendWithBiometricVerification(transfer: Transfer, completion: @escaping SendCompletion) {
        let biometricsPrompt = S.VerifyPin.touchIdMessage
        self.authenticator.signAndSubmit(transfer: transfer,
                                         wallet: self.wallet,
                                         withBiometricsPrompt: biometricsPrompt) { result in
            switch result {
            case .success:
                self.waitForSubmission(of: transfer, completion: completion)
            case .failure, .fallback:
                completion(.creationError(message: S.Send.Error.authenticationError))
            default:
                break
            }
        }
    }

    private func waitForSubmission(of transfer: Transfer, completion: @escaping SendCompletion) {
        let handleSuccess: (_ originatingTx: Transfer?) -> Void = { originatingTx in
            DispatchQueue.main.async {
                self.stopWaitingForSubmission()
                self.setMetaData(originatingTransfer: originatingTx)
                if let protoReq = self.protocolRequest {
                    PaymentRequest.postProtocolPayment(protocolRequest: protoReq, transfer: transfer) {
                        self.displayPaymentProtocolResponse?($0)
                    }
                }
                //TODO:CRYPTO raw tx is only needed by platform, but currently unused
                completion(.success(hash: transfer.hash?.description, rawTx: nil))
            }
        }

        let handleFailure = {
            DispatchQueue.main.async {
                self.stopWaitingForSubmission()
                //TODO:CRYPTO propagate errors
                completion(.publishFailure(code: 0, message: ""))
            }
        }

        let handleTimeout = {
            DispatchQueue.main.async {
                self.stopWaitingForSubmission()
                completion(.publishFailure(code: 0, message: S.Alert.timedOut))
            }
        }

        self.wallet.subscribe(self) { event in
            guard case .transferSubmitted(let eventTransfer, let success) = event,
                eventTransfer.hash == transfer.hash else { return }
            guard success else { return handleFailure() }
            // for token transfers wait for the transaction in the native wallet to be submitted
            guard !self.isOriginatingTransferNeeded else { return }
            handleSuccess(nil)
        }

        if isOriginatingTransferNeeded, let primaryWallet = wallet.networkPrimaryWallet {
            primaryWallet.subscribe(self) { event in
                guard case .transferSubmitted(let eventTransfer, let success) = event,
                    eventTransfer.hash == transfer.hash else { return }
                guard success else { return handleFailure() }
                handleSuccess(eventTransfer)
            }
        }

        DispatchQueue.main.async {
            self.submitTimeoutTimer = Timer.scheduledTimer(withTimeInterval: self.submitTimeout, repeats: false) { _ in
                handleTimeout()
            }
        }
    }

    private func stopWaitingForSubmission() {
        self.wallet.unsubscribe(self)
        if isOriginatingTransferNeeded {
            wallet.networkPrimaryWallet?.unsubscribe(self)
        }
        self.submitTimeoutTimer = nil
    }

    private func setMetaData(originatingTransfer: Transfer? = nil) {
        guard let transfer = transfer,
            let rate = wallet.currency.state?.currentRate else { print("[SEND] missing tx metadata")
            return
        }
        let tx = Transaction(transfer: transfer,
                             wallet: wallet,
                             kvStore: kvStore,
                             rate: rate)
        let feeRate = tx.feeBasis?.pricePerCostFactor.tokenValue.doubleValue

        let newGift: Gift? = gift != nil ? Gift(shared: false,
                                                claimed: false,
                                                reclaimed: false,
                                                txnHash: transfer.hash?.description,
                                                keyData: gift!.keyData,
                                                name: gift!.name,
                                                rate: gift!.rate,
                                                amount: gift!.amount) : nil
        tx.createMetaData(rate: rate,
                          comment: comment,
                          feeRate: feeRate,
                          tokenTransfer: nil,
                          gift: newGift,
                          kvStore: kvStore)

        // for non-native token transfers, the originating transaction on the network's primary wallet captures the fee spent
        if let originatingTransfer = originatingTransfer,
            let originatingWallet = wallet.networkPrimaryWallet,
            let rate = originatingWallet.currency.state?.currentRate {
            assert(isOriginatingTransferNeeded && transfer.hash == originatingTransfer.hash)
            let originatingTx = Transaction(transfer: originatingTransfer,
                                            wallet: originatingWallet,
                                            kvStore: kvStore,
                                            rate: rate)
            originatingTx.createMetaData(rate: rate, tokenTransfer: wallet.currency.code, kvStore: kvStore)
        }
        
        if newGift != nil {
            //gifing needs a delay for some reason
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                print("[gifting] txMetaDataUpdated: \(tx.hash)")
                Store.trigger(name: .txMetaDataUpdated(tx.hash))
            }
        } else {
            DispatchQueue.main.async {
                Store.trigger(name: .txMetaDataUpdated(tx.hash))
            }
        }
    }
}
