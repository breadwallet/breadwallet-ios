//
//  JSONRPCTests.swift
//  breadwalletTests
//
//  Created by Ehsan Rezaie on 2018-03-12.
//  Copyright © 2018-2019 Breadwinner AG. All rights reserved.
//

import XCTest
@testable import breadwallet
@testable import BRCore

// This test will test against the live API at api.breadwallet.com
class JSONRPCClientTests: XCTestCase {
    var authenticator: WalletAuthenticator!
    var client: BRAPIClient!
    
    override func setUp() {
        super.setUp()
        authenticator = FakeAuthenticator() // each test will get its own account
        client = BRAPIClient(authenticator: authenticator)
    }
    
    override func tearDown() {
        super.tearDown()
        authenticator = nil
        client = nil
    }
    
    func testGetBalance() {
        let exp = expectation(description: "request")
        client.getBalance(address: "0xD5034292972ec9e54c7186D38CD39A6F449CCE77") { result in
            switch result {
            case .success(let value):
                XCTAssertEqual(value, "0x0")
            case .error(let error):
                XCTFail("getBalance error: \(error.localizedDescription)")
            }
            exp.fulfill()
        }
        waitForExpectations(timeout: 15, handler: nil)
    }
    
    func testGetGasPrice() {
        let exp = expectation(description: "request")
        client.getGasPrice() { result in
            switch result {
            case .success(let value):
                XCTAssertGreaterThan(value, UInt256(0))
            case .error(let error):
                XCTFail("getGasPrice error: \(error.localizedDescription)")
            }
            exp.fulfill()
        }
        waitForExpectations(timeout: 15, handler: nil)
    }
}
