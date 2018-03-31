//
//  SpendingLimitTests.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-03-28.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import XCTest
@testable import breadwallet

class SpendingLimitTests : XCTestCase {

    private var walletManager: BTCWalletManager?

    override func setUp() {
        super.setUp()
        clearKeychain()
        walletManager = try! BTCWalletManager(currency: Currencies.btc, dbPath: Currencies.btc.dbPath)
        let _ = walletManager?.setRandomSeedPhrase()
        initWallet(walletManager: walletManager!)
    }

    func testDefaultValue() {
        guard let walletManager = walletManager else { return XCTAssert(false, "Wallet manager should not be nil")}
        UserDefaults.standard.removeObject(forKey: "SPEND_LIMIT_AMOUNT")
        XCTAssertTrue(walletManager.spendingLimit == 0, "Default value should be 0")
    }

    func testSaveSpendingLimit() {
        guard let walletManager = walletManager else { return XCTAssert(false, "Wallet manager should not be nil")}
        walletManager.spendingLimit = 100
        XCTAssertTrue(walletManager.spendingLimit == 100)
    }

    func testSaveZero() {
        guard let walletManager = walletManager else { return XCTAssert(false, "Wallet manager should not be nil")}
        walletManager.spendingLimit = 0
        XCTAssertTrue(walletManager.spendingLimit == 0)
    }
}
