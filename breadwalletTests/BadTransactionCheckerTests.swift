//
//  BadBtcTransactionLoggerTests.swift
//  breadwalletTests
//
//  Created by Ray Vander Veen on 2019-01-21.
//  Copyright © 2019 breadwallet LLC. All rights reserved.
//

import XCTest

@testable import breadwallet
@testable import BRCore

class BadTransactionCheckerTests: XCTestCase {

    func testBadTransactionDetection() {
        let checker = BadTransactionChecker()
        XCTAssertEqual(checker.badTransactionCount, 0)
    }

    func testCheckEmptyTransactions() {
        let checker = BadTransactionChecker()
        
        let expectEmptyTransactions = self.expectation(description: "nocallback")
        
        checker.checkTransactions([]) { (transactions) in
            if transactions.isEmpty {
                expectEmptyTransactions.fulfill()
            }
        }
        
        self.waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testCheckNoBadTransactions() {
        let checker = BadTransactionChecker()
        let expectNoInvalidTransactions = self.expectation(description: "no invalid txs")
        
        let validTxs = [ makeMockTransaction(valid: true),
                         makeMockTransaction(valid: true),
                         makeMockTransaction(valid: true)]

        checker.checkTransactions(validTxs) { (transactions) in
            if transactions.isEmpty {
                expectNoInvalidTransactions.fulfill()
            }
        }
        
        self.waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testCheckBadTransactions() {
        let checker = BadTransactionChecker()
        let expectBadTransaction = self.expectation(description: "expect bad transaction")
        
        let txs = [ makeMockTransaction(valid: true),
                    makeMockTransaction(valid: false), // bad transaction
                    makeMockTransaction(valid: true)]

        checker.checkTransactions(txs) { (transactions) in
            if !transactions.isEmpty {
                expectBadTransaction.fulfill()
            }
        }
        
        self.waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testMultipleChecksWithBadTransactions() {
        let checker = BadTransactionChecker()
        let expectNoNewTransactionsReported = self.expectation(description: "no new txs reported")
        
        let badTx = makeMockTransaction(valid: false)
        let goodTx = makeMockTransaction(valid: true)
        
        var badTxCount = 1
        
        let transactions = [badTx, goodTx]
        
        checker.checkTransactions(transactions) { (reportedTxs) in
            // there should be one bad tx reported
            XCTAssertEqual(reportedTxs.count, 1)
            XCTAssertEqual(checker.badTransactionCount, badTxCount)

            // call checkTransactions() again to make sure we don't get called back
            // about the same bad tx
            checker.checkTransactions(transactions, { (reportedTxs) in
                XCTAssertEqual(reportedTxs.count, 0)
                XCTAssertEqual(checker.badTransactionCount, badTxCount)

                // finally toss a new bad tx into the mix with the original tx's to make sure
                // the new one is reported as bad
                let newSet = [badTx, goodTx, makeMockTransaction(valid: false)]
                badTxCount += 1
                
                checker.checkTransactions(newSet, { (reportedTxs) in
                    XCTAssertEqual(reportedTxs.count, 1)
                    XCTAssertEqual(checker.badTransactionCount, badTxCount)
                    expectNoNewTransactionsReported.fulfill()
                })
            })
        }
        
        self.waitForExpectations(timeout: 1, handler: nil)
    }
    
    private func makeMockTransaction(valid: Bool) -> Transaction {
        return MockTransaction(valid: valid)
    }
}

