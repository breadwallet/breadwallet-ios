//
//  WalletCoordinator.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-01-07.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation
import UIKit //TODO - this shouldn't need uikit

private let lastBlockHeightKey = "LastBlockHeightKey"
private let progressUpdateInterval: TimeInterval = 0.5

class WalletCoordinator : Subscriber {

    var kvStore: BRReplicatedKVStore? {
        didSet {
            updateTransactions()
        }
    }

    private let walletManager: WalletManager
    private let store: Store
    private var progressTimer: Timer?
    private let defaults = UserDefaults.standard

    init(walletManager: WalletManager, store: Store) {
        self.walletManager = walletManager
        self.store = store
        addWalletObservers()
        addSubscriptions()
        updateBalance()
    }

    private var lastBlockHeight: UInt32 {
        set {
            defaults.set(newValue, forKey: lastBlockHeightKey)
        }
        get {
            return UInt32(defaults.integer(forKey: lastBlockHeightKey))
        }
    }

    @objc private func updateProgress() {
        if let progress = walletManager.peerManager?.syncProgress(fromStartHeight: lastBlockHeight) {
            DispatchQueue.walletQueue.async {
                if let timestamp = self.walletManager.peerManager?.lastBlockTimestamp {
                    DispatchQueue.main.async {
                        self.store.perform(action: WalletChange.setProgress(progress: progress, timestamp: timestamp))
                    }
                }
            }
        }
        self.updateBalance()
    }

    private func onSyncStart() {
        progressTimer = Timer.scheduledTimer(timeInterval: progressUpdateInterval, target: self, selector: #selector(WalletCoordinator.updateProgress), userInfo: nil, repeats: true)
        store.perform(action: WalletChange.setIsSyncing(true))
        startActivity()
    }

    private func onSyncSucceed() {
        if let height = walletManager.peerManager?.lastBlockHeight {
            self.lastBlockHeight = height
        }
        progressTimer?.invalidate()
        progressTimer = nil
        store.perform(action: WalletChange.setIsSyncing(false))
        endActivity()
    }

    private func onSyncFail(notification: Notification) {
        guard let code = notification.userInfo?["errorCode"] else { return }
        guard let message = notification.userInfo?["errorDescription"] else { return }
        store.perform(action: WalletChange.setSyncingErrorMessage("\(message) (\(code))"))
        endActivity()
    }

    private func updateTransactions() {
        guard let blockHeight = self.walletManager.peerManager?.lastBlockHeight else { return }
        guard let transactions = self.walletManager.wallet?.makeTransactionViewModels(blockHeight: blockHeight, kvStore: kvStore, rate: store.state.currentRate) else { return }
        if transactions.count > 0 {
            self.store.perform(action: WalletChange.setTransactions(transactions))
        }
    }

    private func addWalletObservers() {
        NotificationCenter.default.addObserver(forName: .WalletBalanceChangedNotification, object: nil, queue: nil, using: { note in
            self.updateBalance()
            self.updateTransactions()
        })

        NotificationCenter.default.addObserver(forName: .WalletTxStatusUpdateNotification, object: nil, queue: nil, using: {note in
            self.updateTransactions()
        })

        NotificationCenter.default.addObserver(forName: .WalletTxRejectedNotification, object: nil, queue: nil, using: {note in
            guard let recommendRescan = note.userInfo?["recommendRescan"] as? Bool else { return }
            if recommendRescan {
                self.store.perform(action: RecommendRescan.set(recommendRescan))
            }
        })

        NotificationCenter.default.addObserver(forName: .WalletSyncStartedNotification, object: nil, queue: nil, using: {note in
            self.onSyncStart()
        })

        NotificationCenter.default.addObserver(forName: .WalletSyncSucceededNotification, object: nil, queue: nil, using: {note in
            self.onSyncSucceed()
        })

        NotificationCenter.default.addObserver(forName: .WalletSyncFailedNotification, object: nil, queue: nil, using: {note in
            self.onSyncFail(notification: note)
        })
    }

    private func updateBalance() {
        guard let balance = walletManager.wallet?.balance else { return }
        store.perform(action: WalletChange.setBalance(balance))
    }

    private func addSubscriptions() {
        store.subscribe(self, name: .retrySync, callback: { _ in 
            DispatchQueue.walletQueue.async {
                self.walletManager.peerManager?.connect()
            }
        })

        store.subscribe(self, name: .rescan, callback: { _ in
            self.store.perform(action: RecommendRescan.set(false))
            //In case rescan is called while a sync is in progess
            //we need to make sure it's false before a rescan starts
            //self.store.perform(action: WalletChange.setIsSyncing(false))
            DispatchQueue.walletQueue.async {
                self.walletManager.peerManager?.rescan()
            }
        })
    }

    private func startActivity() {
        UIApplication.shared.isIdleTimerDisabled = true
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
    }

    private func endActivity() {
        UIApplication.shared.isIdleTimerDisabled = false
        UIApplication.shared.isNetworkActivityIndicatorVisible = false
    }
}
