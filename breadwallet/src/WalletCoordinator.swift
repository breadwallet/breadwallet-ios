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

class WalletCoordinator {

    private let walletManager: WalletManager
    private let store: Store
    private var progressTimer: Timer?
    private let defaults = UserDefaults.standard

    init(walletManager: WalletManager, store: Store) {
        self.walletManager = walletManager
        self.store = store

        addWalletObservers()
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
            store.perform(action: WalletChange.setProgress(progress: progress))
        }

        guard let balance = walletManager.wallet?.balance else { return }
        store.perform(action: WalletChange.setBalance(balance))
    }

    private func onSyncStart() {
        progressTimer = Timer.scheduledTimer(timeInterval: progressUpdateInterval, target: self, selector: #selector(WalletCoordinator.updateProgress), userInfo: nil, repeats: true)
        store.perform(action: WalletChange.setIsSyncing(true))
    }

    private func onSyncSucceed() {
        if let height = walletManager.peerManager?.lastBlockHeight {
            self.lastBlockHeight = height
        }
        progressTimer?.invalidate()
        progressTimer = nil
        store.perform(action: WalletChange.setIsSyncing(false))
    }

    private func onSyncFail(notification: Notification) {
        store.perform(action: WalletChange.setIsSyncing(false))
        //TODO - handle this error properly
        let alert = UIAlertController(title: "Error", message: "Syncing Error: \(notification.userInfo!["errorCode"]), \(notification.userInfo!["errorDescription"])", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        UIApplication.shared.keyWindow?.rootViewController?.present(alert, animated: true, completion: nil)
    }

    private func addWalletObservers() {
        NotificationCenter.default.addObserver(forName: .WalletBalanceChangedNotification, object: nil, queue: nil, using: { note in
            guard let balance = self.walletManager.wallet?.balance else { return }
            self.store.perform(action: WalletChange.setBalance(balance))
        })

        NotificationCenter.default.addObserver(forName: .WalletTxStatusUpdateNotification, object: nil, queue: nil, using: {note in
            guard let blockHeight = self.walletManager.peerManager?.lastBlockHeight else { return }
            guard let transactions = self.walletManager.wallet?.makeTransactionViewModels(blockHeight: blockHeight) else { return }
            if transactions.count > 0 {
                self.store.perform(action: WalletChange.setTransactions(transactions))
            }
            print("WalletTxStatusUpdateNotification: \(note)")
        })

        NotificationCenter.default.addObserver(forName: .WalletTxRejectedNotification, object: nil, queue: nil, using: {note in
            print("WalletTxRejectedNotification")
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
}
