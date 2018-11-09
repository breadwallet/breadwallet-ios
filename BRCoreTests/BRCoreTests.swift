//
//  BRCoreTests.swift
//  BRCoreTests
//
//  Created by Ed Gamble on 3/21/18.
//  Copyright © 2018 breadwallet LLC. All rights reserved.
//
import XCTest
import BRCore.Ethereum

class BRCoreTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testCore() {
        XCTAssert(1 == BRRunTests())
    }
    
    func testCoreEthereum () {
        runTests()
        
    }
}
