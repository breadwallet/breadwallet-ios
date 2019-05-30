//
//  Transaction.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2018-01-13.
//  Copyright © 2018 breadwallet LLC. All rights reserved.
//

import Foundation
import BRCore
import BRCrypto

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

enum TransactionDirection: String {
    case sent = "Sent"
    case received = "Received"
    case moved = "Moved"
}

/// Wrapper for BRCrypto TransferFeeBasis
enum FeeBasis {
    case bitcoin(feePerKB: Amount)
    case ethereum(gasPrice: Amount, gasLimit: UInt64)
}

// MARK: -

/// Wrapper for BRCrypto Transfer
class Transaction {
    private let transfer: BRCrypto.Transfer
    let wallet: Wallet

    var currency: Currency { return wallet.currency }
    var confirmations: UInt64 {
        return transfer.confirmations ?? 0
    }
    var blockNumber: UInt64? {
        return transfer.confirmation?.blockNumber
    }
    //TODO:CRYPTO used as non-optional by tx metadata and rescan
    var blockHeight: UInt64 {
        return blockNumber ?? 0
    }

    var targetAddress: String { return transfer.target?.description ?? "" }
    var sourceAddress: String { return transfer.source?.description ?? "" }
    //TODO:CRYPTO legacy support
    var toAddress: String { return targetAddress }
    var fromAddress: String { return sourceAddress }

    var amount: Amount { return Amount(coreAmount: transfer.amount, currency: currency) }
    var fee: Amount { return Amount(coreAmount: transfer.fee, currency: currency) }
    var feeBasis: FeeBasis? {
        switch transfer.feeBasis {
        case .bitcoin(let feePerKB):
            //TODO:CRYPTO Core should provide an Amount instead of UInt64 satoshis
            return .bitcoin(feePerKB: Amount(tokenString: feePerKB.description, currency: currency, unit: currency.baseUnit))
        case .ethereum(let gasPrice, let gasLimit):
            guard let currency = wallet.manager.currency(from: gasPrice.currency) else { assertionFailure(); return nil }
            return .ethereum(gasPrice: Amount(coreAmount: gasPrice, currency: currency), gasLimit: gasLimit)
        }
    }

    var created: Date? {
        if let confirmationTime = transfer.confirmation?.timestamp {
            return Date(timeIntervalSince1970: TimeInterval(confirmationTime))
        } else {
            return nil
        }
    }
    //TODO:CRYPTO legacy
    var timestamp: TimeInterval {
        if let timestamp = transfer.confirmation?.timestamp {
            return TimeInterval(timestamp)
        } else {
            return Date().timeIntervalSince1970
        }
    }

    var hash: String { return transfer.hash?.description ?? "" }

    //TODO:CRYPTO refactor
    var status: TransactionStatus {
        switch transfer.state {
        case .created, .signed, .submitted, .pending:
            return .pending
        case .included:
            switch confirmations {
            case 0:
                return .pending
            case 1..<6:
                return .confirmed
            default:
                return .complete
            }
        case .failed, .deleted:
            return .invalid
        }
    }

    //TODO:CRYPTO refactor -- this wrapper is not needed
    var direction: TransactionDirection {
        switch transfer.direction {
        case .sent: return .sent
        case .received: return .received
        case .recovered: return .moved
        }
    }

    // MARK: Init

    init(transfer: BRCrypto.Transfer, wallet: Wallet) {
        self.transfer = transfer
        self.wallet = wallet
    }
}

extension Transaction {

    var metaData: TxMetaData? { return metaDataContainer?.metaData }
    var comment: String? { return metaData?.comment }

    //TODO:CRYPTO tx metadata
    var metaDataContainer: MetaDataContainer? { return nil }

    //TODO:CRYPTO remove this dependency
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

extension Transaction: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(transfer.hash)
    }
}

// MARK: - Equatable support

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
                                 deviceId: UserDefaults.deviceID,
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
