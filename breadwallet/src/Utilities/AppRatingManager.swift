//
//  AppRatingManager.swift
//  breadwallet
//
//  Created by Ray Vander Veen on 2019-01-23.
//  Copyright © 2019 Breadwinner AG. All rights reserved.
//

import UIKit
import StoreKit

/**
 *  Decides when to trigger an app rating prompt, interfacing with Apple's SKStoreReviewController API.
 */
class AppRatingManager: NSObject, Subscriber, Trackable {
    
    // Make sure recent transactions being viewed are under one day old.
    static public let recentTransactionThreshold: TimeInterval = (24*60*60)

    // Make sure the user has freshly opened the app at least this many times before we trigger a rating prompt.
    public let ratingLaunchCountCycle: Int = 10

    private let ratingPromptAnalyticsEvent = "prompt.review.displayed"
    private let ratingPromptReasonViewedTransactions = "viewedTransactions"
    
    var haveSufficientLaunchesToShowPrompt: Bool {
        return launchCount >= ratingLaunchCountCycle
    }
    
    var launchCount: Int { return UserDefaults.appLaunchCount }
    var launchCountAtLastPrompt: Int { return UserDefaults.appLaunchCountAtLastRatingPrompt }
    
    func shouldTriggerPrompt(transactions: [Transaction]) -> Bool {
        // This trigger can be fired when the PIN screen is still in the foreground and we don't want that.
        // Instead we want the user to see the beauty of a recently completed received transaction when viewing
        // the wallet.
        guard !Store.state.isLoginRequired else { return false }

        // Make sure we've had enough launches since the last time we asked the user to rate the app.
        guard (launchCount - launchCountAtLastPrompt) > ratingLaunchCountCycle else { return false }
        
        let now = Date().timeIntervalSince1970
        let txAgeThreshold = AppRatingManager.recentTransactionThreshold
        var recentReceivedTransaction: Transaction?
        
        func isQualifyingTransaction(tx: Transaction) -> Bool {
            return (now - tx.timestamp) < txAgeThreshold &&
                    tx.direction == .received &&
                    (tx.status == .confirmed || tx.status == .complete)
        }
        
        // Assume transactions are already sorted in reverse-chronological order.
        // Find one that's within the past 24 hours, is received, and completed.
        for tx in transactions where isQualifyingTransaction(tx: tx) {
            recentReceivedTransaction = tx
            break
        }
        
        return recentReceivedTransaction != nil
    }
    
    private func triggerRatingsPrompt(reason: String) {
        SKStoreReviewController.requestReview()
        saveEvent(ratingPromptAnalyticsEvent, attributes: [ "reason": reason])
        
        // Store the current app launch count so we can make sure we don't prompt again until
        // a sufficient number of subsequent app launches.
        UserDefaults.appLaunchCountAtLastRatingPrompt = UserDefaults.appLaunchCount
    }
    
    public func start() {
        
        Store.subscribe(self, name: .didViewTransactions(nil), callback: { (trigger) in
            
            if UserDefaults.debugSuppressAppRatingPrompt {
                return
            }

            if case .didViewTransactions(let transactions)? = trigger {
                if let transactions = transactions, !transactions.isEmpty {
                    DispatchQueue.global(qos: .background).async { [unowned self] in
                        if UserDefaults.debugShowAppRatingOnEnterWallet || self.shouldTriggerPrompt(transactions: transactions) {
                            // Add a slight delay before showing the prompt so the user has a chance
                            // to view the transactions.
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: {
                                self.triggerRatingsPrompt(reason: self.ratingPromptReasonViewedTransactions)
                            })
                        }
                    }
                }
            }
        })
    }
}
