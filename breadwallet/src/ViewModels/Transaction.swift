//
//  Transaction.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2018-01-13.
//  Copyright © 2018 breadwallet LLC. All rights reserved.
//

import Foundation
import BRCore

/// Transacton status
enum TransactionStatus {
    /// Zero confirmations
    case pending
    /// One or more confirmations
    case confirmed
    /// Sufficient confirmations to deem complete (coin-specific)
    case complete
    /// Invalid / error
    case invalid
}

/// Coin-agnostic transaction model wrapper
protocol Transaction {
    var currency: Currency { get }
    var hash: String { get }
    var blockHeight: UInt64 { get }
    var confirmations: UInt64 { get }
    var status: TransactionStatus { get }
    var direction: TransactionDirection { get }
    var timestamp: TimeInterval { get }
    var toAddress: String { get }
    var amount: UInt256 { get }
    
    var metaData: TxMetaData? { get }
    var comment: String? { get }
    var metaDataContainer: MetaDataContainer? { get }
    var kvStore: BRReplicatedKVStore? { get }
    var hasKvStore: Bool { get }
    
    var isPending: Bool { get }
    var isValid: Bool { get }
}

// MARK: Default Values
extension Transaction {
    
    var metaData: TxMetaData? { return metaDataContainer?.metaData }
    var comment: String? { return metaData?.comment }
    var metaDataContainer: MetaDataContainer? { return nil }
    var kvStore: BRReplicatedKVStore? { return nil }
    var hasKvStore: Bool { return kvStore != nil }
    
    var isPending: Bool { return status == .pending }
    var isValid: Bool { return status != .invalid }
    
    func createMetaData(rate: Rate, comment: String? = nil, feeRate: Double? = nil, tokenTransfer: String? = nil) {
        metaDataContainer?.createMetaData(tx: self, rate: rate, comment: comment, feeRate: feeRate, tokenTransfer: tokenTransfer)
    }
    
    func saveComment(comment: String, rate: Rate) {
        guard let metaDataContainer = metaDataContainer else { return }
        metaDataContainer.save(comment: comment, tx: self, rate: rate)
    }
}

// MARK: -

protocol EthLikeTransaction: Transaction {
    var fromAddress: String { get }
    var gasPrice: UInt256 { get }
    var gasLimit: UInt64 { get }
    var gasUsed: UInt64 { get }
}

// MARK: - Equatable support

extension Equatable where Self: Transaction {}

func == (lhs: Transaction, rhs: Transaction) -> Bool {
    return lhs.hash == rhs.hash &&
        lhs.status == rhs.status &&
        lhs.comment == rhs.comment &&
        lhs.hasKvStore == rhs.hasKvStore
}

func == (lhs: [Transaction], rhs: [Transaction]) -> Bool {
    return lhs.elementsEqual(rhs, by: ==)
}

func != (lhs: [Transaction], rhs: [Transaction]) -> Bool {
    return !lhs.elementsEqual(rhs, by: ==)
}

// MARK: - Metadata Container

/// Encapsulates the transaction metadata in the KV store
class MetaDataContainer {
    var metaData: TxMetaData? {
        guard metaDataCache == nil else { return metaDataCache }
        guard let data = TxMetaData(txKey: key, store: kvStore) else { return nil }
        metaDataCache = data
        return metaDataCache
    }
    
    var kvStore: BRReplicatedKVStore
    
    private var key: String
    private var metaDataCache: TxMetaData?
    
    init(key: String, kvStore: BRReplicatedKVStore) {
        self.key = key
        self.kvStore = kvStore
    }
    
    /// Creates and stores new metadata in KV store if it does not exist
    func createMetaData(tx: Transaction, rate: Rate, comment: String? = nil, feeRate: Double? = nil, tokenTransfer: String? = nil) {
        guard metaData == nil else { return }
        
        let newData = TxMetaData(key: key,
                                 transaction: tx,
                                 exchangeRate: rate.rate,
                                 exchangeRateCurrency: rate.code,
                                 feeRate: feeRate ?? 0.0,
                                 deviceId: UserDefaults.standard.deviceID,
                                 comment: comment,
                                 tokenTransfer: tokenTransfer)
        do {
            _ = try kvStore.set(newData)
        } catch let error {
            print("could not update metadata: \(error)")
        }
    }
    
    func save(comment: String, tx: Transaction, rate: Rate) {
        if let metaData = metaData {
            metaData.comment = comment
            do {
                _ = try kvStore.set(metaData)
            } catch let error {
                print("could not update metadata: \(error)")
            }
        } else {
            createMetaData(tx: tx, rate: rate, comment: comment)
        }
    }
}
