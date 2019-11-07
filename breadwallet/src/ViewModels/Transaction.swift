//
//  Transaction.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2018-01-13.
//  Copyright © 2018-2019 Breadwinner AG. All rights reserved.
//

import Foundation
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

/// Wrapper for BRCrypto TransferFeeBasis
struct FeeBasis {
    private let core: TransferFeeBasis
    
    let currency: Currency
    var amount: Amount {
        return Amount(cryptoAmount: core.fee, currency: currency)
    }
    var unit: CurrencyUnit {
        return core.unit
    }
    var pricePerCostFactor: Amount {
        return Amount(cryptoAmount: core.pricePerCostFactor, currency: currency)
    }
    var costFactor: Double {
        return core.costFactor
    }
    
    init(core: TransferFeeBasis, currency: Currency) {
        self.core = core
        self.currency = currency
    }
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

    var targetAddress: String { return transfer.target?.sanitizedDescription ?? "" }
    var sourceAddress: String { return transfer.source?.sanitizedDescription ?? "" }
    var toAddress: String { return targetAddress }
    var fromAddress: String { return sourceAddress }

    var amount: Amount { return Amount(cryptoAmount: transfer.amount, currency: currency) }
    var fee: Amount { return Amount(cryptoAmount: transfer.fee, currency: wallet.feeCurrency) }

    var feeBasis: FeeBasis? {
        guard let core = (transfer.confirmedFeeBasis ?? transfer.estimatedFeeBasis) else { return nil }
        return FeeBasis(core: core,
                        currency: wallet.feeCurrency)
    }

    var created: Date? {
        if let confirmationTimestamp = confirmationTimestamp {
            return Date(timeIntervalSince1970: confirmationTimestamp)
        } else {
            return nil
        }
    }
    /// Confirmation time if confirmed, or current time for pending transactions (seconds since UNIX epoch)
    var timestamp: TimeInterval {
        return confirmationTimestamp ?? Date().timeIntervalSince1970
    }

    private var confirmationTimestamp: TimeInterval? {
        guard let seconds = transfer.confirmation?.timestamp else { return nil }
        let timestamp = TimeInterval(seconds)
        guard timestamp > NSTimeIntervalSince1970 else {
            // compensates for a legacy database migration bug (IOS-1453)
            return timestamp + NSTimeIntervalSince1970
        }
        return timestamp
    }

    var hash: String { return transfer.hash?.description ?? "" }

    var status: TransactionStatus {
        switch transfer.state {
        case .created, .signed, .submitted, .pending:
            return .pending
        case .included:
            switch Int(confirmations) {
            case 0:
                return .pending
            case 1..<currency.confirmationsUntilFinal:
                return .confirmed
            default:
                return .complete
            }
        case .failed, .deleted:
            return .invalid
        }
    }
    
    var isPending: Bool { return status == .pending }
    var isValid: Bool { return status != .invalid }

    var direction: TransferDirection {
        return transfer.direction
    }
    
    // MARK: Metadata
    
    private(set) var metaData: TxMetaData?
    
    var comment: String? { return metaData?.comment }
    
    private var metaDataKey: String? {
        // The hash is a hex string, it was previously converted to bytes through UInt256
        // which resulted in a reverse-order byte array due to UInt256 being little-endian.
        // Reverse bytes to maintain backwards-compatibility with keys derived using the old scheme.
        guard let sha256hash = Data(hexString: hash, reversed: true)?.sha256.hexString else { return nil }
        //TODO:CRYPTO_V2 generic tokens
        return currency.isERC20Token ? "tkxf-\(sha256hash)" : "txn2-\(sha256hash)"
    }
    
    /// Creates and stores new metadata in KV store if it does not exist
    func createMetaData(rate: Rate? = nil,
                        comment: String? = nil,
                        feeRate: Double? = nil,
                        tokenTransfer: String? = nil,
                        kvStore: BRReplicatedKVStore) {
        guard metaData == nil, let key = metaDataKey else { return }
        self.metaData = TxMetaData.create(forTransaction: self,
                                          key: key,
                                          rate: rate,
                                          comment: comment,
                                          feeRate: feeRate,
                                          tokenTransfer: tokenTransfer,
                                          kvStore: kvStore)
    }
    
    /// Updates existing metadata with comment. Creates new metadata with comment + rate if needed
    func save(comment: String, kvStore: BRReplicatedKVStore) {
        if let metaData = metaData, let newMetaData = metaData.save(comment: comment, kvStore: kvStore) {
            self.metaData = newMetaData
        } else {
            let rate = currency.state?.currentRate
            createMetaData(rate: rate, comment: comment, kvStore: kvStore)
        }
    }

    // MARK: Init

    init(transfer: BRCrypto.Transfer, wallet: Wallet, kvStore: BRReplicatedKVStore?, rate: Rate?) {
        self.transfer = transfer
        self.wallet = wallet
        
        if let kvStore = kvStore, let metaDataKey = metaDataKey {
            // load existing metadata if found
            self.metaData = TxMetaData(txKey: metaDataKey, store: kvStore)
            // create metadata for incoming transactions
            // Sender creates metadata for outgoing transactions
            if self.metaData == nil, direction == .received {
                // only set rate if recently confirmed to ensure a relatively recent exchange rate is applied
                createMetaData(rate: (status == .complete) ? nil : rate, kvStore: kvStore)
            }
        }
    }
}

// MARK: - Hashable

extension Transaction: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(transfer.hash)
    }
}

// MARK: - Equatable

func == (lhs: Transaction, rhs: Transaction) -> Bool {
    return lhs.hash == rhs.hash &&
        lhs.status == rhs.status &&
        lhs.comment == rhs.comment
}

func == (lhs: [Transaction], rhs: [Transaction]) -> Bool {
    return lhs.elementsEqual(rhs, by: ==)
}

func != (lhs: [Transaction], rhs: [Transaction]) -> Bool {
    return !lhs.elementsEqual(rhs, by: ==)
}
