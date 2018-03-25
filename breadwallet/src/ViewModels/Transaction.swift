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
    var currency: CurrencyDef { get }
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
    var hasKvStore: Bool { get }
    
    var isPending: Bool { get }
    var isValid: Bool { get }
}

// MARK: Default Values
extension Transaction {
    var metaData: TxMetaData? { return nil }
    var comment: String? { return metaData?.comment }
    var hasKvStore: Bool { return false }
    var isPending: Bool {
        return status == .pending
    }
}

// MARK: -

protocol EthLikeTransaction: Transaction {
    var fromAddress: String { get }
}


// MARK: - Equatable support

extension Equatable where Self: Transaction {}

func ==(lhs: Transaction, rhs: Transaction) -> Bool {
    return lhs.hash == rhs.hash &&
        lhs.status == rhs.status &&
        lhs.comment == rhs.comment &&
        lhs.hasKvStore == rhs.hasKvStore
}

func ==(lhs: [Transaction], rhs: [Transaction]) -> Bool {
    return lhs.elementsEqual(rhs, by: ==)
}

func !=(lhs: [Transaction], rhs: [Transaction]) -> Bool {
    return !lhs.elementsEqual(rhs, by: ==)
}
