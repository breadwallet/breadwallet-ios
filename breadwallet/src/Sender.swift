//
//  Sender.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-01-16.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation
import UIKit
import BRCore

enum SendResult {
    case success
    case creationError(String)
    case publishFailure(BRPeerManagerError)
}

private let protocolPaymentTimeout: TimeInterval = 20.0

class Sender {

    init(walletManager: WalletManager, kvStore: BRReplicatedKVStore, currency: CurrencyDef) {
        self.walletManager = walletManager
        self.kvStore = kvStore
        self.currency = currency
    }

    private let walletManager: WalletManager
    private let kvStore: BRReplicatedKVStore
    private let currency: CurrencyDef
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

    var canUseBiometrics: Bool {
        guard let tx = transaction else  { return false }
        return walletManager.canUseBiometrics(forTx: tx)
    }

    func feeForTx(amount: UInt64) -> UInt64? {
        let fee = walletManager.wallet?.feeForTx(amount:amount)
        return fee == 0 ? nil : fee
    }

    //Amount in bits
    func send(biometricsMessage: String, rate: Rate?, comment: String?, feePerKb: UInt64, verifyPinFunction: @escaping (@escaping(String) -> Void) -> Void, completion:@escaping (SendResult) -> Void) {
        guard let tx = transaction else { return completion(.creationError(S.Send.createTransactionError)) }

        self.rate = rate
        self.comment = comment
        self.feePerKb = feePerKb

        if UserDefaults.isBiometricsEnabled && walletManager.canUseBiometrics(forTx:tx) {
            DispatchQueue.walletQueue.async { [weak self] in
                guard let myself = self else { return }
                myself.walletManager.signTransaction(tx, forkId: (myself.currency as! Bitcoin).forkId, biometricsPrompt: biometricsMessage, completion: { result in
                    if result == .success {
                        myself.publish(completion: completion)
                    } else {
                        if result == .failure || result == .fallback {
                            myself.verifyPin(tx: tx, verifyPinFunction: verifyPinFunction, completion: completion)
                        }
                    }
                })
            }
        } else {
            self.verifyPin(tx: tx, verifyPinFunction: verifyPinFunction, completion: completion)
        }
    }

    private func verifyPin(tx: BRTxRef,
                           verifyPinFunction: (@escaping(String) -> Void) -> Void,
                           completion:@escaping (SendResult) -> Void) {
        verifyPinFunction({ pin in
            let group = DispatchGroup()
            group.enter()
            DispatchQueue.walletQueue.async {
                if self.walletManager.signTransaction(tx, forkId: (self.currency as! Bitcoin).forkId, pin: pin) {
                    self.publish(completion: completion)
                }
                group.leave()
            }
            let result = group.wait(timeout: .now() + 4.0)
            if result == .timedOut {
                fatalError("send-tx-timeout")
            }
        })
    }

    private func publish(completion: @escaping (SendResult) -> Void) {
        guard let tx = transaction else { assert(false, "publish failure"); return }
        DispatchQueue.walletQueue.async { [weak self] in
            guard let myself = self else { assert(false, "myelf didn't exist"); return }
            myself.walletManager.peerManager?.publishTx(tx, completion: { success, error in
                DispatchQueue.main.async {
                    if let error = error {
                        completion(.publishFailure(error))
                    } else {
                        myself.setMetaData()
                        completion(.success)
                        myself.postProtocolPaymentIfNeeded()
                    }
                }
            })
        }
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
        Store.trigger(name: .txMemoUpdated(tx.pointee.txHash.description))
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
