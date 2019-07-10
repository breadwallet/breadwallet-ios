//
//  SpendingLimitTests.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-03-28.
//  Copyright © 2017-2019 Breadwinner AG. All rights reserved.
//

import XCTest
@testable import breadwallet

class SpendingLimitTests : XCTestCase {

    //TODO:CRYPTO spend limit
    /*
    private var walletManager: BTCWalletManager!
    private var keyStore: KeyStore!

    override func setUp() {
        super.setUp()
        clearKeychain()
        keyStore = try! KeyStore.create()
        walletManager = setupNewWallet(keyStore: keyStore)
    }

    override func tearDown() {
        super.tearDown()
        clearKeychain()
        keyStore.destroy()
    }

    func testDefaultValue() {
        UserDefaults.standard.removeObject(forKey: "SPEND_LIMIT_AMOUNT")
        XCTAssertTrue(walletManager.spendingLimit == 0, "Default value should be 0")
    }

    func testSaveSpendingLimit() {
        walletManager.spendingLimit = 100
        XCTAssertTrue(walletManager.spendingLimit == 100)
    }

    func testSaveZero() {
        walletManager.spendingLimit = 0
        XCTAssertTrue(walletManager.spendingLimit == 0)
    }
 */
}
