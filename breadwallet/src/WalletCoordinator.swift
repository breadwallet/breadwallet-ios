//
//  WalletCoordinator.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-01-07.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation

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
            store.perform(action: WalletStateAction.setProgress(progress: progress))
        }
    }

    private func addWalletObservers() {
        NotificationCenter.default.addObserver(forName: .WalletBalanceChangedNotification, object: nil, queue: nil, using: { note in
            print("WalletBalanceChangedNotification")
        })

        NotificationCenter.default.addObserver(forName: .WalletTxStatusUpdateNotification, object: nil, queue: nil, using: {note in
            print("WalletTxStatusUpdateNotification")
        })

        NotificationCenter.default.addObserver(forName: .WalletTxRejectedNotification, object: nil, queue: nil, using: {note in
            print("WalletTxRejectedNotification")
        })

        NotificationCenter.default.addObserver(forName: .WalletSyncStartedNotification, object: nil, queue: nil, using: {note in
            self.progressTimer = Timer.scheduledTimer(timeInterval: progressUpdateInterval, target: self, selector: #selector(WalletCoordinator.updateProgress), userInfo: nil, repeats: true)
        })

        NotificationCenter.default.addObserver(forName: .WalletSyncSucceededNotification, object: nil, queue: nil, using: {note in
            if let height = self.walletManager.peerManager?.lastBlockHeight {
                self.lastBlockHeight = height
            }
            self.progressTimer?.invalidate()
            self.progressTimer = nil
        })

        NotificationCenter.default.addObserver(forName: .WalletSyncFailedNotification, object: nil, queue: nil, using: {note in
            print("WalletSyncFailedNotification")
        })
    }

}
