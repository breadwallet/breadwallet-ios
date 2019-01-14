//
//  BtcWalletManager.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2018-04-04.
//  Copyright © 2018 breadwallet LLC. All rights reserved.
//

import Foundation
import BRCore
import SystemConfiguration
import UIKit

// A WalletManger instance manages a single wallet, and that wallet's individual connection to the bitcoin network.
// After instantiating a WalletManager object, call myWalletManager.peerManager.connect() to begin syncing.
class BTCWalletManager: WalletManager, Subscriber {
    let currency: Currency
    var masterPubKey = BRMasterPubKey()
    var earliestKeyTime: TimeInterval = 0
    var db: CoreDatabase?
    var wallet: BRWallet?
    var peerManager: BRPeerManager?
    private let progressUpdateInterval: TimeInterval = 0.5
    private let updateDebounceInterval: TimeInterval = 0.4
    private var progressTimer: Timer?
 
    // Last block height allows us to display the progress from where the sync stopped
    // during the previous app life cycle to the last block in the chain. e.g., if the previous
    // sync successfully sync'd up to block 100,000 and the current sync is at block 200,000 out of 
    // 300,000 total blocks the percent will show 50% (half way between 100,000 and 300,000).
    //
    // 'lastBlockHeight' is updated in syncStopped() if there is no error.
    private var lastBlockHeight: UInt32 {
        set { 
            UserDefaults.setLastSyncedBlockHeight(height: newValue, for: currency)
        }
        get { 
            return UserDefaults.lastSyncedBlockHeight(for: currency)
        }
    }
    
    private var retryTimer: RetryTimer?
    private var updateTimer: Timer?
    var kvStore: BRReplicatedKVStore? {
        didSet { requestTxUpdate() }
    }

    func initWallet(callback: @escaping (Bool) -> Void) {
        guard let db = db else { return callback(false) }
        guard self.masterPubKey != BRMasterPubKey() else {
            assert(false)
            return callback(false)
        }
        db.loadTransactions { txns in
            self.wallet = BRWallet(transactions: txns, masterPubKey: self.masterPubKey, listener: self, currency: self.currency)
            if let wallet = self.wallet {
                Store.perform(action: WalletChange(self.currency).setBalance(UInt256(wallet.balance)))
                Store.perform(action: WalletChange(self.currency)
                    .set(self.currency.state!.mutate(receiveAddress: wallet.receiveAddress,
                                                     legacyReceiveAddress: wallet.legacyReceiveAddress)))
            }
            callback(self.wallet != nil)
        }
    }

    func initWallet(transactions: [BRTxRef]) {
        guard self.masterPubKey != BRMasterPubKey() else {
            return assert(false)
        }
        self.wallet = BRWallet(transactions: transactions, masterPubKey: self.masterPubKey, listener: self, currency: self.currency)
        if let wallet = self.wallet {
            Store.perform(action: WalletChange(self.currency).setBalance(UInt256(wallet.balance)))
            Store.perform(action: WalletChange(self.currency)
                .set(self.currency.state!.mutate(receiveAddress: wallet.receiveAddress,
                                                 legacyReceiveAddress: wallet.legacyReceiveAddress)))
        }
    }

    func initPeerManager(blocks: [BRBlockRef?]) {
        guard let wallet = self.wallet else { return }
        self.peerManager = BRPeerManager(currency: currency, wallet: wallet, earliestKeyTime: earliestKeyTime,
                                         blocks: blocks, peers: [], listener: self)
    }

    func initPeerManager(callback: @escaping () -> Void) {
        db?.loadBlocks { [unowned self] blocks in
            self.db?.loadPeers { peers in
                guard let wallet = self.wallet else { return }
                self.peerManager = BRPeerManager(currency: self.currency, wallet: wallet, earliestKeyTime: self.earliestKeyTime,
                                                 blocks: blocks, peers: peers, listener: self)
                callback()
            }
        }
    }

    init(currency: Currency, masterPubKey: BRMasterPubKey, earliestKeyTime: TimeInterval, dbPath: String? = nil) throws {
        self.currency = currency
        self.masterPubKey = masterPubKey
        self.earliestKeyTime = earliestKeyTime
        guard self.masterPubKey != BRMasterPubKey() else { return }
        if let path = dbPath {
            self.db = CoreDatabase(dbPath: path)
        } else {
            self.db = CoreDatabase()
        }
        listenForSegwitOptIn()
    }

    var isWatchOnly: Bool {
        let mpkData = Data(masterPubKey: masterPubKey)
        return mpkData.isEmpty
    }
    
    func listenForSegwitOptIn() {
        guard currency.matches(Currencies.btc) else { return }
        Store.subscribe(self, name: .optInSegWit, callback: { [weak self] _ in
            guard let `self` = self else { return }
            UserDefaults.hasOptedInSegwit = true
            if let receiveAddress = self.wallet?.receiveAddress {
                Store.perform(action: WalletChange(self.currency).set(self.currency.state!.mutate(receiveAddress: receiveAddress)))
            }
        })
    }
}

extension BTCWalletManager: BRPeerManagerListener, Trackable {

    func syncStarted() {
        print("[\(currency.code)] sync started")
        DispatchQueue.main.async {
            self.db?.setDBFileAttributes()
            self.progressTimer = Timer.scheduledTimer(timeInterval: self.progressUpdateInterval,
                                                      target: self,
                                                      selector: #selector(self.updateProgress),
                                                      userInfo: nil,
                                                      repeats: true)
            Store.perform(action: WalletChange(self.currency).setSyncingState(.syncing))
        }
    }

    func syncStopped(_ error: BRPeerManagerError?) {
        DispatchQueue.main.async {
            if UIApplication.shared.applicationState != .active {
                DispatchQueue.walletQueue.async {
                    self.peerManager?.disconnect()
                }
                return
            }

            switch error {
            case .some(let .posixError(errorCode, description)):
                print("[\(self.currency.code)] sync error: \(description) (\(errorCode))")
                Store.perform(action: WalletChange(self.currency).setSyncingState(.connecting))
                self.saveEvent("event.syncErrorMessage", attributes: ["message": "\(description) (\(errorCode))"])
                if self.retryTimer == nil && self.networkIsReachable() {
                    self.retryTimer = RetryTimer()
                    self.retryTimer?.callback = strongify(self) { _ in
                        Store.trigger(name: .retrySync(self.currency))
                    }
                    self.retryTimer?.start()
                }
            case .none:
                self.retryTimer?.stop()
                self.retryTimer = nil
                if let height = self.peerManager?.lastBlockHeight {
                    self.lastBlockHeight = height
                }
                self.progressTimer?.invalidate()
                self.progressTimer = nil
                Store.perform(action: WalletChange(self.currency).setSyncingState(.success))
                Store.perform(action: WalletChange(self.currency).setIsRescanning(false))
                print("[\(self.currency.code)] sync completed - block height \(self.lastBlockHeight)")
            }
        }
    }

    func txStatusUpdate() {
        DispatchQueue.main.async { [weak self] in
            self?.requestTxUpdate()
        }
    }

    func saveBlocks(_ replace: Bool, _ blocks: [BRBlockRef?]) {
        db?.saveBlocks(replace, blocks)
    }

    func savePeers(_ replace: Bool, _ peers: [BRPeer]) {
        db?.savePeers(replace, peers)
    }

    func networkIsReachable() -> Bool {
        var flags: SCNetworkReachabilityFlags = []
        var zeroAddress = sockaddr()
        zeroAddress.sa_len = UInt8(MemoryLayout<sockaddr>.size)
        zeroAddress.sa_family = sa_family_t(AF_INET)
        guard let reachability = SCNetworkReachabilityCreateWithAddress(nil, &zeroAddress) else { return false }
        if !SCNetworkReachabilityGetFlags(reachability, &flags) { return false }
        return flags.contains(.reachable) && !flags.contains(.connectionRequired)
    }

    @objc private func updateProgress() {
        DispatchQueue.walletQueue.async {
            guard let progress = self.peerManager?.syncProgress(fromStartHeight: self.lastBlockHeight),
                let timestamp = self.peerManager?.lastBlockTimestamp else { return }
            DispatchQueue.main.async {
                Store.perform(action: WalletChange(self.currency).setProgress(progress: progress, timestamp: timestamp))
                if let wallet = self.wallet {
                    Store.perform(action: WalletChange(self.currency).setBalance(UInt256(wallet.balance)))
                }
            }
        }
    }
}

extension BTCWalletManager: BRWalletListener {
    func balanceChanged(_ balance: UInt64) {
        DispatchQueue.main.async { [weak self] in
            guard let myself = self else { return }
            myself.checkForReceived(newBalance: balance)
            Store.perform(action: WalletChange(myself.currency).setBalance(UInt256(balance)))
            myself.requestTxUpdate()
        }
    }

    func txAdded(_ tx: BRTxRef) {
        db?.txAdded(tx)
    }

    func txUpdated(_ txHashes: [UInt256], blockHeight: UInt32, timestamp: UInt32) {
        db?.txUpdated(txHashes, blockHeight: blockHeight, timestamp: timestamp)
    }

    func txDeleted(_ txHash: UInt256, notifyUser: Bool, recommendRescan: Bool) {
        if notifyUser && recommendRescan {
            DispatchQueue.main.async { [weak self] in
                guard let `self` = self else { return }
                self.saveEvent("event.recommendRescan")
                Store.trigger(name: .automaticRescan(self.currency))
            }
        }
        DispatchQueue.main.async { [weak self] in
            self?.requestTxUpdate()
        }
        db?.txDeleted(txHash, notifyUser: notifyUser, recommendRescan: true)
    }

    private func checkForReceived(newBalance: UInt64) {
        if let oldBalance = currency.state?.balance?.asUInt64 {
            if newBalance > oldBalance {
                if let walletState = currency.state {
                    Store.perform(action: WalletChange(currency)
                        .set(walletState.mutate(receiveAddress: wallet?.receiveAddress,
                                                legacyReceiveAddress: wallet?.legacyReceiveAddress)))
                    if currency.state?.syncState == .success {
                        showReceived(amount: newBalance - oldBalance)
                    }
                }
            }
        }
    }

    private func showReceived(amount: UInt64) {
        if let rate = currency.state?.currentRate {
            let tokenAmount = Amount(amount: UInt256(amount),
                                     currency: currency,
                                     rate: nil,
                                     minimumFractionDigits: 0)
            let fiatAmount = Amount(amount: UInt256(amount),
                                    currency: currency,
                                    rate: rate,
                                    minimumFractionDigits: 0)
            let primary = Store.state.isBtcSwapped ? fiatAmount.description : tokenAmount.description
            let secondary = Store.state.isBtcSwapped ? tokenAmount.description : fiatAmount.description
            let message = String(format: S.TransactionDetails.received, "\(primary) (\(secondary))")
            Store.trigger(name: .lightWeightAlert(message))
            showLocalNotification(message: message)
            ping()
        }
    }

    private func requestTxUpdate() {
        if updateTimer == nil {
            updateTimer = Timer.scheduledTimer(timeInterval: updateDebounceInterval, target: self, selector: #selector(updateTransactions), userInfo: nil, repeats: false)
        }
    }

    @objc private func updateTransactions() {
        updateTimer?.invalidate()
        updateTimer = nil
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let myself = self else { return }
            guard let txRefs = myself.wallet?.transactions else { return }
            guard let currentRate = myself.currency.state?.currentRate else { return }
            let transactions = myself.makeTransactionViewModels(transactions: txRefs,
                                                                rate: currentRate)
            if !transactions.isEmpty {
                DispatchQueue.main.async {
                    Store.perform(action: WalletChange(myself.currency).setTransactions(transactions))
                }
            }
        }
    }

    func makeTransactionViewModels(transactions: [BRTxRef?], rate: Rate?) -> [Transaction] {
        return transactions.compactMap { $0 }.sorted {
            if $0.pointee.timestamp == 0 {
                return true
            } else if $1.pointee.timestamp == 0 {
                return false
            } else {
                return $0.pointee.timestamp > $1.pointee.timestamp
            }
            }.compactMap {
                return BtcTransaction($0, walletManager: self, kvStore: kvStore, rate: rate)
        }
    }
}
