//
//  BtcTransaction.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2018-01-12.
//  Copyright © 2018 breadwallet LLC. All rights reserved.
//

import Foundation
import BRCore

/// Wrapper for BTC transaction model + metadata
struct BtcTransaction: Transaction {
    
    // MARK: Transaction Properties
    
    let currency: CurrencyDef
    let hash: String
    let status: TransactionStatus
    let direction: TransactionDirection
    let toAddress: String
    let timestamp: TimeInterval
    let blockHeight: UInt64
    let confirmations: UInt64
    let isValid: Bool
    
    var hasKvStore: Bool {
        return kvStore != nil
    }
    
    // MARK: BTC-specific properties
    
    var rawTransaction: BRTransaction? {
        return tx.pointee
    }
    
    var metaData: TxMetaData? {
        return metaDataContainer?.metaData
    }
    
    let amount: UInt256
    let fee: UInt64
    let startingBalance: UInt64
    let endingBalance: UInt64
    
    // MARK: Private
    
    private let tx: BRTxRef
    private let metaDataContainer: MetaDataContainer?
    private let kvStore: BRReplicatedKVStore?
    
    // MARK: - Init
    
    init?(_ tx: BRTxRef, walletManager: BTCWalletManager, kvStore: BRReplicatedKVStore?, rate: Rate?) {
        guard let wallet = walletManager.wallet,
            let peerManager = walletManager.peerManager else { return nil }
        self.currency = walletManager.currency
        self.tx = tx
        self.kvStore = kvStore
        
        let amountReceived = wallet.amountReceivedFromTx(tx)
        let amountSent = wallet.amountSentByTx(tx)
        
        let fee = wallet.feeForTx(tx) ?? 0
        self.fee = fee
        
        // addresses from outputs
        let myAddress = tx.outputs.filter({ output in
            wallet.containsAddress(output.swiftAddress)
        }).first?.swiftAddress ?? ""
        let otherAddress = tx.outputs.filter({ output in
            !wallet.containsAddress(output.swiftAddress)
        }).first?.swiftAddress ?? ""
        
        // direction
        var direction: TransactionDirection
        if amountSent > 0 && (amountReceived + fee) == amountSent {
            direction = .moved
        } else if amountSent > 0 {
            direction = .sent
        } else {
            direction = .received
        }
        self.direction = direction
        
        let endingBalance: UInt64 = wallet.balanceAfterTx(tx)
        var startingBalance: UInt64
        var address: String
        var amount: UInt64
        switch direction {
        case .received:
            address = myAddress
            amount = amountReceived
            startingBalance = endingBalance.subtractingReportingOverflow(amount).0.subtractingReportingOverflow(fee).0
        case .sent:
            address = otherAddress
            amount = amountSent - amountReceived - fee
            startingBalance = endingBalance.addingReportingOverflow(amount).0.addingReportingOverflow(fee).0
        case .moved:
            address = myAddress
            amount = amountSent
            startingBalance = endingBalance.addingReportingOverflow(self.fee).0
        }
        self.amount = UInt256(amount)
        self.startingBalance = startingBalance
        self.endingBalance = endingBalance
        
        toAddress = currency.matches(Currencies.bch) ? address.bCashAddr : address
        
        hash = tx.pointee.txHash.description
        timestamp = TimeInterval(tx.pointee.timestamp)
        isValid = wallet.transactionIsValid(tx)
        blockHeight = (tx.pointee.blockHeight == UInt32.max) ? UInt64.max :  UInt64(tx.pointee.blockHeight)
        
        let lastBlockHeight = UInt64(peerManager.lastBlockHeight)
        confirmations = blockHeight > lastBlockHeight
            ? 0
            : (lastBlockHeight - blockHeight) + 1
        
        if isValid {
            switch confirmations {
            case 0:
                status = .pending
            case 1..<6:
                status = .confirmed
            default:
                status = .complete
            }
        } else {
            status = .invalid
        }
        
        if let kvStore = kvStore {
            metaDataContainer = MetaDataContainer(key: tx.pointee.txHash.txKey, kvStore: kvStore)
            if let rate = rate,
                confirmations < 6 && direction == .received {
                metaDataContainer!.createMetaData(tx: tx, rate: rate)
            }
        } else {
            metaDataContainer = nil
        }
    }
    
    // MARK: -
    
    func saveComment(comment: String, rate: Rate) {
        guard let metaDataContainer = metaDataContainer else { return }
        metaDataContainer.save(comment: comment, tx: tx, rate: rate)
    }
}

/// Encapsulates the transaction metadata in the KV store
class MetaDataContainer {
    var metaData: TxMetaData? {
        get {
            guard metaDataCache == nil else { return metaDataCache }
            guard let data = TxMetaData(txKey: key, store: kvStore) else { return nil }
            metaDataCache = data
            return metaDataCache
        }
    }
    
    private var key: String
    private var kvStore: BRReplicatedKVStore
    private var metaDataCache: TxMetaData?
    
    init(key: String, kvStore: BRReplicatedKVStore) {
        self.key = key
        self.kvStore = kvStore
    }
    
    /// Creates and stores new metadata in KV store if it does not exist
    func createMetaData(tx: BRTxRef, rate: Rate, comment: String? = nil) {
        guard metaData == nil else { return }
        
        let newData = TxMetaData(transaction: tx.pointee,
                                 exchangeRate: rate.rate,
                                 exchangeRateCurrency: rate.code,
                                 feeRate: 0.0,
                                 deviceId: UserDefaults.standard.deviceID)
        if let comment = comment {
            newData.comment = comment
        }
        do {
            let _ = try kvStore.set(newData)
        } catch let error {
            print("could not update metadata: \(error)")
        }
    }
    
    func save(comment: String, tx: BRTxRef, rate: Rate) {
        if let metaData = metaData {
            metaData.comment = comment
            do {
                let _ = try kvStore.set(metaData)
            } catch let error {
                print("could not update metadata: \(error)")
            }
        } else {
            createMetaData(tx: tx, rate: rate, comment: comment)
        }
    }
}
