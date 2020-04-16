// 
//  AccountInitializationTests.swift
//  breadwalletTests
//
//  Created by Adrian Corscadden on 2020-04-15.
//  Copyright © 2020 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import Foundation
import XCTest
@testable import breadwallet

private var client: BRAPIClient?
private var keyStore: KeyStore!
private var system: CoreSystem!

class AccountInitializationTests : XCTestCase {

    override class func setUp() {
        super.setUp()
        clearKeychain()
        deleteKvStoreDb()
        keyStore = try! KeyStore.create()
        let account = setupNewAccount(keyStore: keyStore)
        Backend.connect(authenticator: keyStore)
        client = Backend.apiClient
        system = CoreSystem(keyStore: keyStore)
        system.create(account: account!, authToken: "")
    }
    
    override class func tearDown() {
        super.tearDown()
        system.shutdown(completion: nil)
        Backend.disconnectWallet()
        clearKeychain()
        keyStore.destroy()
    }
    
    func testInitializeHbar() {
        let exp = expectation(description: "Wallet initialization")
        Store.trigger(name: .createAccount(TestCurrencies.hbar, { wallet in
            XCTAssertNotNil(wallet, "Wallet should not be nil")
            exp.fulfill()
        }))
        waitForExpectations(timeout: 30.0, handler: nil)
    }
    
}
