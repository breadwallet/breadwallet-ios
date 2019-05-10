//
//  AppRatingManagerTests.swift
//  breadwalletTests
//
//  Created by Ray Vander Veen on 2019-01-23.
//  Copyright © 2019 breadwallet LLC. All rights reserved.
//

import XCTest

@testable import breadwallet
@testable import BRCore

class AppRatingManagerTests: XCTestCase {

    override func setUp() {
        UserDefaults.resetAll()
    }
    
    private func makeRatingManager() -> AppRatingManager {
        let mgr = AppRatingManager()
        mgr.start()
        return mgr
    }
    
    func testStartAppRatingManager() {
        XCTAssertFalse(makeRatingManager().haveSufficientLaunchesToShowPrompt)
    }

    func testNumberOfLaunches() {
        let mgr = makeRatingManager()
        
        XCTAssertFalse(mgr.haveSufficientLaunchesToShowPrompt)
        
        let launchCount = mgr.minimumLaunchCountForRating
        
        for _ in 1...launchCount { mgr.bumpLaunchCount() }
        
        XCTAssertTrue(mgr.haveSufficientLaunchesToShowPrompt)
    }

    //TODO:CRYPTO MockTransaction
    /*
    func testShouldTriggerRatingWithRecentCompletedTransactions() {
        
        Store.perform(action: Reset())  // resets login requirement to false
        
        let ratingManager = makeRatingManager()
        
        ratingManager.setLaunchCount(1)
        
        // create some recent, received transactions
        var transactions = [MockTransaction]()
        let now = Date().timeIntervalSince1970
        
        transactions.append(MockTransaction(timestamp: now - (AppRatingManager.recentTransactionThreshold - 60),
                                            direction: .received,
                                            status: .complete))
        transactions.append(MockTransaction(timestamp: now - (AppRatingManager.recentTransactionThreshold - 3600),
                                            direction: .received,
                                            status: .complete))
        
        // should not trigger yet because number of launches is still insufficient
        XCTAssertFalse(ratingManager.shouldTriggerPrompt(transactions: transactions))
        
        ratingManager.setLaunchCount(ratingManager.minimumLaunchCountForRating)
        // should trigger now because minimum number of launches has been reached
        XCTAssertTrue(ratingManager.shouldTriggerPrompt(transactions: transactions))
    }
    
    func testShouldTriggerRatingWithRecentConfirmedTransactions() {
        
        Store.perform(action: Reset())  // resets login requirement to false
        
        let ratingManager = makeRatingManager()
        
        ratingManager.setLaunchCount(1)
        
        // create some recent, received transactions
        var transactions = [MockTransaction]()
        let now = Date().timeIntervalSince1970
        
        transactions.append(MockTransaction(timestamp: now - (AppRatingManager.recentTransactionThreshold - 60),
                                            direction: .received,
                                            status: .confirmed))
        transactions.append(MockTransaction(timestamp: now - (AppRatingManager.recentTransactionThreshold - 3600),
                                            direction: .received,
                                            status: .confirmed))
        
        // should not trigger yet because number of launches is still insufficient
        XCTAssertFalse(ratingManager.shouldTriggerPrompt(transactions: transactions))

        ratingManager.setLaunchCount(ratingManager.minimumLaunchCountForRating)
        // should trigger now because minimum number of launches has been reached
        XCTAssertTrue(ratingManager.shouldTriggerPrompt(transactions: transactions))
    }
    
    func testShouldNotTriggerRatingWithOlderTransactions() {
        Store.perform(action: Reset())  // resets login requirement to false
        
        let ratingManager = makeRatingManager()
        
        // create some received transactions that are a bit older than the rating manager's threshold for recency
        var transactions = [MockTransaction]()
        let now = Date().timeIntervalSince1970
        let txTimestamp = now - AppRatingManager.recentTransactionThreshold - 100
        
        transactions.append(MockTransaction(timestamp: txTimestamp,
                                            direction: .received,
                                            status: .complete))
        transactions.append(MockTransaction(timestamp: txTimestamp - 1,
                                            direction: .received,
                                            status: .complete))
        
        // should not trigger the prompt, because the transactions are older
        XCTAssertFalse(ratingManager.shouldTriggerPrompt(transactions: transactions))
    }
    
    func testShouldNotTriggerRatingIfLoginRequired() {
        Store.perform(action: RequireLogin())
       
        let ratingManager = makeRatingManager()
        
        // pass a recent received transaction, but login is required, so the prompt should not be triggered
        let recentTx = MockTransaction(timestamp: Date().timeIntervalSince1970, direction: .received, status: .complete)
        XCTAssertFalse(ratingManager.shouldTriggerPrompt(transactions: [recentTx]))
    }
    
    func testShouldNotTriggerIfNoRecentReceivedTransactions() {
        Store.perform(action: Reset())  // resets login requirement to false
        
        let ratingManager = makeRatingManager()
        let now = Date().timeIntervalSince1970
        
        var transactions = [MockTransaction]()
        
        transactions.append(MockTransaction(timestamp: now,
                                            direction: .sent,
                                            status: .complete))
        transactions.append(MockTransaction(timestamp: now,
                                            direction: .received,
                                            status: .pending))
        
        // should not trigger the prompt because the tx's are either sent or not complete
        XCTAssertFalse(ratingManager.shouldTriggerPrompt(transactions: transactions))
    }
    */
}
