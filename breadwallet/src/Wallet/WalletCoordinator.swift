//
//  WalletCoordinator.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-01-07.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation
import UIKit

//Coordinates the sync state of all wallet managers to
//display the activity indicator and control backtround tasks
class WalletCoordinator : Subscriber, Trackable {

    private var backgroundTaskId: UIBackgroundTaskIdentifier?
    private var reachability = ReachabilityMonitor()
    private var walletManagers: [String: WalletManager]

    init(walletManagers: [String: WalletManager]) {
        self.walletManagers = walletManagers
        addSubscriptions()
    }

    private func addSubscriptions() {
        reachability.didChange = { [weak self] isReachable in
            self?.reachabilityDidChange(isReachable: isReachable)
        }

        //Listen for sync state changes in all wallets
        Store.subscribe(self, selector: {
            for (key, val) in $0.wallets {
                if val.syncState != $1.wallets[key]!.syncState {
                    return true
                }
            }
            return false
        }, callback: { [weak self] state in
            self?.syncStateDidChange(state: state)
        })

        Store.state.currencies.forEach { currency in
            Store.subscribe(self, name: .retrySync(currency), callback: { _ in
                DispatchQueue.walletQueue.async {
                    self.walletManagers[currency.code]?.peerManager?.connect()
                }
            })

            Store.subscribe(self, name: .rescan(currency), callback: { _ in
                Store.perform(action: WalletChange(currency).setRecommendScan(false))
                Store.perform(action: WalletChange(currency).setIsRescanning(true))
                DispatchQueue.walletQueue.async {
                    self.walletManagers[currency.code]?.peerManager?.rescan()
                }
            })
        }
    }

    private func syncStateDidChange(state: State) {
        let allWalletsFinishedSyncing = state.wallets.values.filter { $0.syncState == .success}.count == state.wallets.values.count
        if allWalletsFinishedSyncing {
            endActivity()
            endBackgroundTask()
        } else {
            startActivity()
            startBackgroundTask()
        }
    }

    private func endBackgroundTask() {
        if let taskId = backgroundTaskId {
            UIApplication.shared.endBackgroundTask(taskId)
            backgroundTaskId = nil
        }
    }

    private func startBackgroundTask() {
        guard backgroundTaskId == nil else { return }
        backgroundTaskId = UIApplication.shared.beginBackgroundTask(expirationHandler: {
            DispatchQueue.walletQueue.async {
                self.walletManagers.values.forEach {
                    $0.peerManager?.disconnect()
                }
            }
        })
    }

    private func reachabilityDidChange(isReachable: Bool) {
        if !isReachable {
            DispatchQueue.walletQueue.async {
                self.walletManagers.values.forEach {
                    $0.peerManager?.disconnect()
                }
                DispatchQueue.main.async {
                    Store.state.currencies.forEach {
                        Store.perform(action: WalletChange($0).setSyncingState(.connecting))
                    }
                }
            }
        }
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
