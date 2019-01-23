//
//  AppRatingManager.swift
//  breadwallet
//
//  Created by Ray Vander Veen on 2019-01-23.
//  Copyright © 2019 breadwallet LLC. All rights reserved.
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
    public let minimumLaunchCountForRating: Int = 10

    private let launchCountKey = "com.breadwallet.app.launch.count"
    private let ratingPromptAnalyticsEvent = "prompt.review.displayed"
    private let ratingPromptReasonViewedTransactions = "viewedTransactions"
    
    // This is passed to the start() method to facilitate unit testing.
    var userDefaults: UserDefaults = UserDefaults.standard
    
    var haveSufficientLaunchesToShowPrompt: Bool {
        return launchCount >= minimumLaunchCountForRating
    }
    
    var launchCount: Int {
        return userDefaults.integer(forKey: launchCountKey)
    }
    
    func shouldTriggerPrompt(transactions: [Transaction]) -> Bool {
        // This trigger can be fired when the PIN screen is still in the foreground and we don't want that.
        // Instead we want the user to see the beauty of a recently completed received transaction when viewing
        // the wallet.
        guard !Store.state.isLoginRequired else { return false }

        guard launchCount >= minimumLaunchCountForRating else { return false }
        
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
        
        // Reset the launch count so we don't try to trigger it again too soon.
        setLaunchCount(0)
    }
    
    public func start(_ userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
        
        bumpLaunchCount()
        
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
    
    // This is called by the ApplicationController when the app takes the foreground.
    func bumpLaunchCount() {
        setLaunchCount(launchCount + 1)
    }
    
    func setLaunchCount(_ count: Int) {
        userDefaults.set(count, forKey: launchCountKey)
    }
}
