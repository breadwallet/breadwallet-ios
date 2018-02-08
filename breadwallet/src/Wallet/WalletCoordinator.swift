//
//  WalletCoordinator.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-01-07.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation
import UIKit

class WalletCoordinator : Subscriber, Trackable {

    private let currency: CurrencyDef
    private let walletManager: WalletManager
    private var backgroundTaskId: UIBackgroundTaskIdentifier?
    private var reachability = ReachabilityMonitor()

    init(walletManager: WalletManager, currency: CurrencyDef) {
        self.currency = currency
        self.walletManager = walletManager
        addSubscriptions()
        reachability.didChange = { [weak self] isReachable in
            self?.reachabilityDidChange(isReachable: isReachable)
        }

    }

    private func endBackgroundTask() {
        if let taskId = backgroundTaskId {
            UIApplication.shared.endBackgroundTask(taskId)
            backgroundTaskId = nil
        }
    }

    private func startBackgroundTask() {
        backgroundTaskId = UIApplication.shared.beginBackgroundTask(expirationHandler: {
            DispatchQueue.walletQueue.async {
                self.walletManager.peerManager?.disconnect()
            }
        })
    }

    private func reachabilityDidChange(isReachable: Bool) {
        if !isReachable {
            DispatchQueue.walletQueue.async {
                self.walletManager.peerManager?.disconnect()
                DispatchQueue.main.async {
                    Store.perform(action: WalletChange(self.currency).setSyncingState(.connecting))
                }
            }
        }
    }

    private func addSubscriptions() {
        Store.subscribe(self, name: .retrySync, callback: { _ in
            DispatchQueue.walletQueue.async {
                self.walletManager.peerManager?.connect()
            }
        })

        Store.subscribe(self, name: .rescan, callback: { _ in
            Store.perform(action: WalletChange(self.currency).setRecommendScan(false))
            //In case rescan is called while a sync is in progess
            //we need to make sure it's false before a rescan starts
            //self.store.perform(action: WalletChange(currency).setIsSyncing(false))
            DispatchQueue.walletQueue.async {
                self.walletManager.peerManager?.rescan()
            }
        })

        Store.subscribe(self, name: .rescan, callback: { _ in
            Store.perform(action: WalletChange(self.currency).setIsRescanning(true))
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
