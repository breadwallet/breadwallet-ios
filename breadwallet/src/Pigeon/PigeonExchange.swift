//
//  PigeonExchange.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2018-07-24.
//  Copyright © 2018-2019 Breadwinner AG. All rights reserved.
//

import Foundation
import BRCrypto
import UIKit

// swiftlint:disable type_body_length
// swiftlint:disable cyclomatic_complexity

struct WalletPairingRequest {
    let publicKey: String
    let identifier: String
    let service: String
    let returnToURL: URL?
    
    static var empty: WalletPairingRequest = WalletPairingRequest(publicKey: "", identifier: "", service: "", returnToURL: nil)
}

enum WalletPairingResult {
    case success
    case error(message: String)
}

enum CheckoutResult {
    case accepted(result: SendResult)
    case declined
}

typealias PairingCompletionHandler = (WalletPairingResult) -> Void

class PigeonExchange: Subscriber {
    private unowned let apiClient: BRAPIClient
    private unowned let kvStore: BRReplicatedKVStore
    private var timer: Timer?
    private let fetchInterval: TimeInterval = 3.0

    init?() {
        guard let kvStore = Backend.kvStore else { return nil }
        self.apiClient = Backend.apiClient
        self.kvStore = kvStore
        
        Store.subscribe(self, name: .linkWallet(WalletPairingRequest.empty, false, {_ in})) { [unowned self] in
            guard case .linkWallet(let pairingRequest, let accepted, let callback)? = $0 else { return }
            if accepted {
                self.acceptPairingRequest(pairingRequest, completionHandler: callback)
            } else {
                self.rejectPairingRequest(pairingRequest, completionHandler: callback)
            }
        }
        
        Store.subscribe(self, name: .fetchInbox) { [unowned self] _ in
            self.fetchInbox()
        }
        
        Store.lazySubscribe(self,
                            selector: { $0.isPushNotificationsEnabled != $1.isPushNotificationsEnabled },
                            callback: { [weak self] state in
                                if state.isPushNotificationsEnabled {
                                    self?.stopPolling()
                                } else {
                                    self?.startPolling()
                                }
        })
    }
    
    deinit {
        stopPolling()
        Store.unsubscribe(self)
    }
    
    // MARK: - Pairing

    private func acceptPairingRequest(_ pairingRequest: WalletPairingRequest, completionHandler: @escaping PairingCompletionHandler) {
        guard let authKey = apiClient.authKey,
            let walletID = Store.state.walletID,
            let idData = walletID.data(using: .utf8),
            let localIdentifier = idData.sha256.hexString.hexToData else {
                return completionHandler(.error(message: "Error constructing local Identifier"))
        }
        
        guard let pairingKey = PigeonCrypto.pairingKey(forIdentifier: pairingRequest.identifier, authKey: authKey),
            let remotePubKey = pairingRequest.publicKey.hexToData,
            let localPubKey = pairingKey.encodeAsPublic.hexToData else {
                print("[EME] invalid pairing request parameters. pairing aborted!")
                return completionHandler(.error(message: "invalid pairing request parameters. pairing aborted!"))
        }
        
        var link = MessageLink()
        link.id = localIdentifier
        link.publicKey = localPubKey
        link.status = .accepted
        guard let envelope = try? MessageEnvelope(to: remotePubKey,
                                                  from: localPubKey,
                                                  message: link,
                                                  type: .link,
                                                  service: pairingRequest.service,
                                                  crypto: PigeonCrypto(privateKey: pairingKey))
            else {
                print("[EME] envelope construction failed!")
                return completionHandler(.error(message: "envelope construction failed"))
        }
        
        print("[EME] initiate LINK! remote pubkey: \(remotePubKey.base58), local pubkey: \(localPubKey.base58)")
        
        var finished = false
        let backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "EME Pairing") {
            // background time expired
            if !finished {
                completionHandler(.error(message: "timed out waiting for link response. pairing aborted!"))
            }
        }
        
        let finish: PairingCompletionHandler = { result in
            finished = true
            completionHandler(result)
            UIApplication.shared.endBackgroundTask(backgroundTask)
        }
        
        // register public key
        // send link message
        // wait for link response
        // add remote wallet info to KV store
        apiClient.addAssociatedKey(localPubKey) { success in
            guard success else {
                print("[EME] associated key could not be added. pairing aborted!")
                return finish(.error(message: "associated key could not be added. pairing aborted!"))
            }

            self.apiClient.sendMessage(envelope: envelope) { (success) in
                guard success else {
                    print("[EME] failed to send LINK message. pairing aborted!")
                    return finish(.error(message: "failed to send LINK message. pairing aborted!"))
                }
                
                // if pairing from a moble browser, open the browser to complete the handshake
                if let returnToURL = pairingRequest.returnToURL {
                    UIApplication.shared.open(returnToURL)
                }
                
                // poll inbox and wait for LINK response
                let fetchInterval = 3.0
                let maxTries = 10
                var count = 0
                
                Timer.scheduledTimer(withTimeInterval: fetchInterval, repeats: true) { (timer) in
                    self.apiClient.fetchInbox(afterCursor: self.lastCursor) { result in
                        guard case .success(let entries) = result else {
                            print("[EME] /inbox fetch error. pairing aborted!")
                            timer.invalidate()
                            finish(.error(message: "EME fetch error. Pairing aborted!"))
                            return
                        }

                        // ignore non-LINK type messages before pairing succeeds
                        let linkEntries: [(InboxEntry, MessageEnvelope)] = entries.unacknowledged.compactMap { entry in
                            guard let envelope = entry.envelope else {
                                self.apiClient.sendAck(forCursor: entry.cursor)
                                return nil
                            }
                            return (entry, envelope)
                            }.filter {
                                let envelope = $0.1
                                guard let type = PigeonMessageType(rawValue: envelope.messageType), type == .link else {
                                    print("[EME] WARNING: unexpected message type during pairing: \(envelope.messageType)")
                                    return false
                                }
                                return true
                        }

                        guard !linkEntries.isEmpty else {
                            if !timer.isValid {
                                print("[EME] timed out waiting for link response. pairing aborted!")
                                finish(.error(message: "timed out waiting for link response. pairing aborted!"))
                            }
                            return
                        }
                        
                        // from this point on it will either succeed or fail, cancel the timer
                        timer.invalidate()
                        
                        for entryAndEnvelope in linkEntries {
                            let entry = entryAndEnvelope.0
                            let envelope = entryAndEnvelope.1
                            self.apiClient.sendAck(forCursor: entry.cursor)
                            
                            guard envelope.verify(pairingKey: pairingKey) else {
                                print("[EME] envelope verification failed!")
                                continue
                            }
                            
                            guard let decryptedData = PigeonCrypto(privateKey: pairingKey)
                                .decrypt(envelope.encryptedMessage,
                                         nonce: envelope.nonce,
                                         senderPublicKey: envelope.senderPublicKey) else {
                                            print("[EME] decryption failed!")
                                            continue
                            }
                            guard let link = try? MessageLink(serializedData: decryptedData) else {
                                print("[EME] failed to decode link message")
                                continue
                            }
                            guard link.status == .accepted else {
                                print("[EME] remote rejected link request. pairing aborted!")
                                finish(.error(message: "remote rejected link request. pairing aborted!"))
                                return
                            }
                            guard let remoteID = String(data: link.id, encoding: .utf8), remoteID == pairingRequest.identifier else {
                                print("[EME] link message identifier did not match pairing wallet identifier. aborted!")
                                finish(.error(message: "link message identifier did not match pairing wallet identifier. aborted!"))
                                return
                            }
                            
                            self.addRemoteEntity(remotePubKey: link.publicKey, identifier: remoteID, service: pairingRequest.service)
                            self.startPolling(forPairing: true) // poll until account request is processed
                            finish(.success)
                            break
                        }
                    } // fetchInbox
                    
                    count += 1
                    if count >= maxTries {
                        timer.invalidate()
                    }
                } // scheduledTimer
            } // sendMessage
        }
    }
    
    private func rejectPairingRequest(_ pairingRequest: WalletPairingRequest, completionHandler: @escaping PairingCompletionHandler) {
        guard let authKey = apiClient.authKey,
            let pairingKey = PigeonCrypto.pairingKey(forIdentifier: pairingRequest.identifier, authKey: authKey),
            let pairingPubKey = pairingKey.encodeAsPublic.hexToData,
            let remotePubKey = pairingRequest.publicKey.hexToData else {
                return completionHandler(.error(message: "error constructing remote pub key"))
        }
        
        var link = MessageLink()
        link.status = .rejected
        link.error = .userDenied
        guard let envelope = try? MessageEnvelope(to: remotePubKey,
                                                  from: pairingPubKey,
                                                  message: link,
                                                  type: .link,
                                                  service: pairingRequest.service,
                                                  crypto: PigeonCrypto(privateKey: pairingKey)) else {
            print("[EME] envelope construction failed!")
            return completionHandler(.error(message: "envelope construction failed!"))
        }
        
        print("[EME] rejecting LINK! remote pubkey: \(remotePubKey.base58)")
        
        self.apiClient.sendMessage(envelope: envelope, callback: { (success) in
            guard success else {
                print("[EME] failed to send LINK message")
                return completionHandler(.error(message: "failed to send LINK message"))
            }
            completionHandler(.success)
        })
    }
    
    // MARK: - Inbox
    
    func fetchInbox() {
        let limit = 100
        apiClient.fetchInbox(afterCursor: lastCursor, limit: limit) { [weak self] result in
            guard let `self` = self else { return }
            switch result {
            case .success(let entries):
                print("[EME] /inbox fetched \(entries.unacknowledged.count) new entries")
                if let lastCursor = self.processEntries(entries) {
                    self.updateLastCursor(lastCursor)
                    if entries.count == limit {
                        self.fetchInbox()
                    }
                }
            case .error:
                print("[EME] fetch error")
            }
        }
    }

    func startPolling(forPairing isPairing: Bool = false) {
        guard isPairing || isPaired else { return }
        print("[EME] start polling")
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: fetchInterval, repeats: true, block: { [weak self] _ in
            self?.fetchInbox()
        })
    }

    func stopPolling() {
        print("[EME] stop polling")
        timer?.invalidate()
    }
    
    /// returns the cursor of the last processed entry
    private func processEntries(_ entries: [InboxEntry]) -> String? {
        var lastCursor: String?
        var hasSkippedEntry = false
        entries.unacknowledged.forEach { entry in
            guard let envelope = entry.envelope else {
                // unable to decode envelope -- ack to avoid future processing
                apiClient.sendAck(forCursor: entry.cursor)
                if !hasSkippedEntry {
                    lastCursor = entry.cursor
                }
                return
            }
            if self.processEnvelope(envelope) {
                apiClient.sendAck(forCursor: entry.cursor)
                if !hasSkippedEntry {
                    lastCursor = entry.cursor
                }
            } else {
                // skipped entry, do not update cursor for any further entries
                hasSkippedEntry = true
            }
        }
        return lastCursor
    }
    
    private func updateLastCursor(_ cursor: String) {
        let inboxMetadata = InboxMetaData(store: kvStore) ?? InboxMetaData(cursor: cursor)
        inboxMetadata.lastCursor = cursor
        
        do {
            try _ = kvStore.set(inboxMetadata)
            print("[EME] inbox cursor updated: \(cursor)")
        } catch let error {
            print("[EME] error saving inbox metadata: \(error.localizedDescription)")
        }
    }
    
    private var lastCursor: String? {
        return InboxMetaData(store: kvStore)?.lastCursor
    }

    // returns: shouldSendAck: Bool
    private func processEnvelope(_ envelope: MessageEnvelope) -> Bool {
        guard let pairingKey = pairingKey(forRemotePubKey: envelope.senderPublicKey) else {
            print("[EME] remote entity not found!")
            return true
        }
        guard envelope.verify(pairingKey: pairingKey) else {
            print("[EME] envelope \(envelope.identifier) verification failed!")
            return true
        }
        print("[EME] envelope \(envelope.identifier) verified. contains \(envelope.service) \(envelope.messageType) message")
        let crypto = PigeonCrypto(privateKey: pairingKey)
        guard let decryptedData = crypto.decrypt(envelope.encryptedMessage, nonce: envelope.nonce, senderPublicKey: envelope.senderPublicKey) else {
            print("[EME] envelope \(envelope.identifier) decryption failed!")
            return true
        }
        do {
            guard let type = PigeonMessageType(rawValue: envelope.messageType) else {
                print("[EME] ERROR: Unknown message type \(envelope.messageType)")
                return true
            }
            
            switch type {
            case .link:
                print("[EME] WARNING: received LINK message outside of pairing sequence.")
                return false
            case .ping:
                let ping = try MessagePing(serializedData: decryptedData)
                print("[EME] PING: \(ping.ping)")
                sendPong(message: ping.ping, toPing: envelope)
            case .pong:
                let pong = try MessagePong(serializedData: decryptedData)
                print("[EME] PONG: \(pong.pong)")
            case .accountRequest:
                let request = try MessageAccountRequest(serializedData: decryptedData)
                sendAccountResponse(for: request, to: envelope)
                if Store.state.isPushNotificationsEnabled {
                    stopPolling()
                }
            case .paymentRequest:
                let request = try MessagePaymentRequest(serializedData: decryptedData)
                handlePaymentRequest(request, from: envelope)
            case .callRequest:
                let request = try MessageCallRequest(serializedData: decryptedData)
                handleCallRequest(request, from: envelope)
            default:
                assertionFailure("unexpected message type")
            }
            return true
        } catch let error {
            print("[EME] message decrypt error: \(error)")
            return false
        }
    }
    
    // MARK: - Account Request
    
    private func sendAccountResponse(for accountRequest: MessageAccountRequest, to requestEnvelope: MessageEnvelope) {
        guard let pairingKey = pairingKey(forRemotePubKey: requestEnvelope.senderPublicKey) else {
            print("[EME] remote entity not found!")
            return
        }
        
        let currencyCode = accountRequest.scope.uppercased()
        let currencyId = CurrencyId(rawValue: currencyCode) //TODO:CRYPTO_V2 code to uid
        var response = MessageAccountResponse()
        if let receiveAddress = Store.state.wallets[currencyId]?.receiveAddress {
            response.scope = accountRequest.scope
            response.address = receiveAddress
            response.status = .accepted
        } else {
            response.status = .rejected
        }
        
        guard let envelope = try? MessageEnvelope(replyTo: requestEnvelope,
                                                  message: response,
                                                  type: .accountResponse,
                                                  crypto: PigeonCrypto(privateKey: pairingKey))
            else {
                return print("[EME] envelope construction failed!")
        }
        apiClient.sendMessage(envelope: envelope)
    }
    
    // MARK: - Purchase/Call Request
    
    private func handlePaymentRequest(_ paymentRequest: MessagePaymentRequest, from requestEnvelope: MessageEnvelope) {
        //TODO:CRYPTO cleanup
        guard let currency = Store.state.currencies.first(where: { $0.isEthereum }) else { return assertionFailure() }
        var request = MessagePaymentRequestWrapper(paymentRequest: paymentRequest, currency: currency)
        request.responseCallback = { result in
            self.sendPaymentResponse(result: result, forRequest: paymentRequest, from: requestEnvelope)
        }
        Store.perform(action: RootModalActions.Present(modal: .sendForRequest(request: request)))
    }
    
    private func handleCallRequest(_ callRequest: MessageCallRequest, from requestEnvelope: MessageEnvelope) {
        //TODO:CRYPTO cleanup
        guard let currency = Store.state.currencies.first(where: { $0.isEthereum }) else { return assertionFailure() }
        var request = MessageCallRequestWrapper(callRequest: callRequest, currency: currency)
        request.responseCallback = { result in
            self.sendCallResponse(result: result, forRequest: callRequest, from: requestEnvelope)
        }
        Store.perform(action: RootModalActions.Present(modal: .sendForRequest(request: request)))
    }

    private func sendPaymentResponse(result: CheckoutResult, forRequest: MessagePaymentRequest, from requestEnvelope: MessageEnvelope) {
        guard let pairingKey = pairingKey(forRemotePubKey: requestEnvelope.senderPublicKey) else {
            print("[EME] remote entity not found!")
            return
        }
        var response = MessagePaymentResponse()
        switch result {
        case .accepted(let sendResult):
            switch sendResult {
            case .success(let txHash, _):
                response.scope = forRequest.scope
                response.status = .accepted
                response.transactionID = txHash ?? "unknown txHash"
            case .creationError:
                response.status = .rejected
                response.error = .transactionFailed
            case .publishFailure:
                response.status = .rejected
                response.error = .transactionFailed
            case .insufficientGas:
                response.status = .rejected
                response.error = .transactionFailed
            }
        case .declined:
            response.status = .rejected
            response.error = .userDenied
        }
        
        guard let envelope = try? MessageEnvelope(replyTo: requestEnvelope,
                                                  message: response,
                                                  type: .paymentResponse,
                                                  crypto: PigeonCrypto(privateKey: pairingKey))
            else {
                return print("[EME] envelope construction failed!")
        }
        apiClient.sendMessage(envelope: envelope)
    }

    private func sendCallResponse(result: CheckoutResult, forRequest request: MessageCallRequest, from requestEnvelope: MessageEnvelope) {
        guard let pairingKey = pairingKey(forRemotePubKey: requestEnvelope.senderPublicKey) else {
            print("[EME] remote entity not found!")
            return
        }
        var response = MessageCallResponse()
        var responseTxHash: String?
        switch result {
        case .accepted(let sendResult):
            switch sendResult {
            case .success(let txHash, _):
                response.scope = request.scope
                response.status = .accepted
                response.transactionID = txHash ?? "unknown txHash"
                responseTxHash = txHash
            case .creationError:
                response.status = .rejected
                response.error = .transactionFailed
            case .publishFailure:
                response.status = .rejected
                response.error = .transactionFailed
            case .insufficientGas:
                response.status = .rejected
                response.error = .transactionFailed
            }
        case .declined:
            response.status = .rejected
            response.error = .userDenied
        }
            
        guard let envelope = try? MessageEnvelope(replyTo: requestEnvelope, message: response, type: .callResponse, crypto: PigeonCrypto(privateKey: pairingKey)) else {
            return print("[EME] envelope construction failed!")
        }
        apiClient.sendMessage(envelope: envelope)

        //TODO:CRYPTO cleanup
        guard let currency = Store.state.currencies.first(where: { $0.isEthereum }) else { return assertionFailure() }

        let requestWrapper = MessageCallRequestWrapper(callRequest: request, currency: currency)
        requestWrapper.getToken { [unowned self] token in
            let amountToReceive = ""
            var tokenCode = ""
            if let token = token {
                self.addTokenWallet(token: token)
                tokenCode = token.code
            }
            let currencyId = CurrencyId(rawValue: request.scope) //TODO:CRYPTO_V2 code to uid
            self.apiClient.sendCheckoutEvent(status: response.status.rawValue,
                                             identifier: requestEnvelope.identifier,
                                             service: requestEnvelope.service,
                                             fromCurrency: request.scope,
                                             fromAddress: Store.state.wallets[currencyId]?.receiveAddress ?? "",
                                             fromAmount: requestWrapper.purchaseAmount.tokenUnformattedString(in: requestWrapper.currency.defaultUnit),
                                             toCurrency: tokenCode,
                                             toAmount: amountToReceive,
                                             toAddress: request.address,
                                             txHash: responseTxHash,
                                             error: (response.status == .rejected ) ? response.error.rawValue : nil)
        }
    }
    
    // MARK: - Ping
    
    func sendPing(remotePubKey: Data) {
        guard let pairingKey = pairingKey(forRemotePubKey: remotePubKey),
            let pairingPubKey = pairingKey.encodeAsPublic.hexToData else { return }

        let crypto = PigeonCrypto(privateKey: pairingKey)

        var ping = MessagePing()
        ping.ping = "Hello from BC"
        guard let envelope = try? MessageEnvelope(to: remotePubKey, from: pairingPubKey, message: ping, type: .ping, service: "PWB", crypto: crypto) else {
            return print("[EME] envelope construction failed!")
        }
        apiClient.sendMessage(envelope: envelope)
    }
    
    private func sendPong(message: String, toPing ping: MessageEnvelope) {
        guard let pairingKey = pairingKey(forRemotePubKey: ping.senderPublicKey) else { return }
        assert(pairingKey.encodeAsPublic == ping.receiverPublicKey.hexString)
        var pong = MessagePong()
        pong.pong = message
        guard let envelope = try? MessageEnvelope(replyTo: ping, message: pong, type: .pong, crypto: PigeonCrypto(privateKey: pairingKey)) else {
            return print("[EME] envelope construction failed!")
        }
        apiClient.sendMessage(envelope: envelope)
    }
    
    // MARK: - Paired Wallets
    
    var pairedWallets: PairedWalletIndex? {
        return PairedWalletIndex(store: kvStore)
    }

    // returns true if wallet is paired with any EME services
    var isPaired: Bool {
        return pairedWallets?.hasPairedWallets ?? false
    }

    /// Removes all paired wallets
    func resetPairedWallets() {
        guard let index = PairedWalletIndex(store: kvStore) else { return }

        stopPolling()

        let pwdToRemove = index.pubKeys.compactMap { PairedWalletData(remotePubKey: $0, store: kvStore) }
        index.pubKeys.removeAll()
        index.services.removeAll()

        do {
            try _ = kvStore.set(index)
            for pwd in pwdToRemove {
                try _ = kvStore.del(pwd)
            }
            try _ = kvStore.del(index)
            print("[EME] removed all paired wallet data")
        } catch let error {
            print("[EME] error saving paired wallet info: \(error.localizedDescription)")
        }
    }
    
    private func addRemoteEntity(remotePubKey: Data, identifier: String, service: String) {
        let existingIndex = PairedWalletIndex(store: kvStore)
        let index = existingIndex ?? PairedWalletIndex()
        
        let pubKeyBase64 = remotePubKey.base64EncodedString()
        
        guard !index.pubKeys.contains(pubKeyBase64),
            PairedWalletData(remotePubKey: pubKeyBase64, store: kvStore) == nil else {
                print("[EME] ERROR: paired wallet already exists")
                return
        }
        
        index.pubKeys.append(pubKeyBase64)
        index.services.append(service)
        
        let pwd = PairedWalletData(remotePubKey: pubKeyBase64, remoteIdentifier: identifier, service: service)
        
        do {
            try _ = kvStore.set(pwd)
            try _ = kvStore.set(index)
            print("[EME] paired wallet info saved")
        } catch let error {
            print("[EME] error saving paired wallet info: \(error.localizedDescription)")
        }
    }
    
    private func pairingKey(forRemotePubKey remotePubKey: Data) -> Key? {
        guard let pwd = PairedWalletData(remotePubKey: remotePubKey.base64EncodedString(), store: kvStore) else { return nil }
        return PigeonCrypto.pairingKey(forIdentifier: pwd.identifier, authKey: apiClient.authKey!)
    }

    private func addTokenWallet(token: Currency) {
        //TODO:CRYPTO to add a wallet need access to System wallets
        /*
        guard !Store.state.displayCurrencies.contains(where: {$0.code.lowercased() == token.code.lowercased()}) else { return }
        var walletDict = [String: WalletState]()
        walletDict[token.code] = WalletState.initial(token, displayOrder: Store.state.displayCurrencies.count)
        let metaData = CurrencyListMetaData(kvStore: self.kvStore)!
        //TODO:CRYPTO token address / user wallets
        //metaData.addTokenAddresses(addresses: [token.address])
        do {
            _ = try self.kvStore.set(metaData)
        } catch let error {
            print("error setting wallet info: \(error)")
        }
        DispatchQueue.main.async {
            Store.perform(action: ManageWallets.AddWallets(walletDict))
        }
         */
    }
}
