//
//  Sender.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-01-16.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation
import BRCore

enum SendResult {
    case success
    case creationError(String)
    case publishFailure(BRPeerManagerError)
}

private let protocolPaymentTimeout: TimeInterval = 20.0

class Sender {

    init(walletManager: WalletManager, kvStore: BRReplicatedKVStore, store: Store) {
        self.walletManager = walletManager
        self.kvStore = kvStore
        self.store = store
    }

    private let walletManager: WalletManager
    private let kvStore: BRReplicatedKVStore
    private let store: Store
    var transaction: BRTxRef?
    var protocolRequest: PaymentProtocolRequest?
    var rate: Rate?
    var comment: String?
    var feePerKb: UInt64?

    func createTransaction(amount: UInt64, to: String) -> Bool {
        transaction = walletManager.wallet?.createTransaction(forAmount: amount, toAddress: to)
        return transaction != nil
    }

    func createTransaction(forPaymentProtocol: PaymentProtocolRequest) {
        protocolRequest = forPaymentProtocol
        transaction = walletManager.wallet?.createTxForOutputs(forPaymentProtocol.details.outputs)
    }

    var fee: UInt64 {
        guard let tx = transaction else { return 0 }
        return walletManager.wallet?.feeForTx(tx) ?? 0
    }

    func feeForTx(amount: UInt64) -> UInt64 {
        return walletManager.wallet?.feeForTx(amount:amount) ?? 0
    }

    //For display purposes only
    func maybeCanUseTouchId(forAmount: UInt64) -> Bool {
        return forAmount < walletManager.spendingLimit && UserDefaults.isTouchIdEnabled
    }

    //Amount in bits
    func send(touchIdMessage: String, rate: Rate?, comment: String?, feePerKb: UInt64, verifyPinFunction: @escaping (@escaping(String) -> Bool) -> Void, completion:@escaping (SendResult) -> Void) {
        guard let tx = transaction else { return completion(.creationError(S.Send.createTransactionError)) }

        self.rate = rate
        self.comment = comment
        self.feePerKb = feePerKb

        if UserDefaults.isTouchIdEnabled && walletManager.canUseTouchID(forTx:tx) {
            walletManager.signTransaction(tx, touchIDPrompt: touchIdMessage, completion: { success in
                if success {
                    self.publish(completion: completion)
                } else {
                    self.verifyPin(tx: tx, withFunction: verifyPinFunction, completion: completion)
                }
            })
        } else {
            self.verifyPin(tx: tx, withFunction: verifyPinFunction, completion: completion)
        }
    }

    private func verifyPin(tx: BRTxRef, withFunction: (@escaping(String) -> Bool) -> Void, completion:@escaping (SendResult) -> Void) {
        withFunction({ pin in
            if self.walletManager.signTransaction(tx, pin: pin) {
                self.publish(completion: completion)
                return true
            } else {
                return false
            }
        })
    }

    private func publish(completion: @escaping (SendResult) -> Void) {
        guard let tx = transaction else { return }
        walletManager.peerManager?.publishTx(tx, completion: { [weak self] success, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.publishFailure(error))
                } else {
                    self?.setMetaData()
                    completion(.success)
                    self?.postProtocolPaymentIfNeeded()
                }
            }
        })
    }

    private func setMetaData() {
        guard let rate = rate, let tx = transaction, let feePerKb = feePerKb else { print("Incomplete tx metadata"); return }
        let metaData = TxMetaData(transaction: tx.pointee,
                                  exchangeRate: rate.rate,
                                  exchangeRateCurrency: rate.code,
                                  feeRate: Double(feePerKb),
                                  deviceId: UserDefaults.standard.deviceID,
                                  comment: comment)
        do {
            let _ = try kvStore.set(metaData)
        } catch let error {
            print("could not update metadata: \(error)")
        }
        store.trigger(name: .txMemoUpdated(tx.pointee.txHash.description))
    }

    private func postProtocolPaymentIfNeeded() {
        guard let protoReq = protocolRequest else { return }
        guard let wallet = walletManager.wallet else { return }
        let amount = protoReq.details.outputs.map { $0.amount }.reduce(0, +)
        let payment = PaymentProtocolPayment(merchantData: protoReq.details.merchantData,
                                             transactions: [transaction],
                                             refundTo: [(address: wallet.receiveAddress, amount: amount)])
        guard let urlString = protoReq.details.paymentURL else { return }
        guard let url = URL(string: urlString) else { return }

        let request = NSMutableURLRequest(url: url, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: protocolPaymentTimeout)

        request.setValue("application/bitcoin-payment", forHTTPHeaderField: "Content-Type")
        request.addValue("application/bitcoin-paymentack", forHTTPHeaderField: "Accept")
        request.httpMethod = "POST"
        request.httpBody = Data(bytes: payment!.bytes)

        URLSession.shared.dataTask(with: request as URLRequest) { data, response, error in
            guard error == nil else { print("payment error: \(error!)"); return }
            guard let response = response, let data = data else { print("no response or data"); return }
            if response.mimeType == "application/bitcoin-paymentack" && data.count <= 50000 {
                if let ack = PaymentProtocolACK(data: data) {
                    print("received ack: \(ack)") //TODO - show memo to user
                } else {
                    print("ack failed to deserialize")
                }
            } else {
                print("invalid data")
            }

            print("finished!!")
        }.resume()

    }
}
