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

    private let walletManager: WalletManager = try! WalletManager(store: Store(), dbPath: nil)

    override func setUp() {
        super.setUp()
        clearKeychain()
        let _ = walletManager.setRandomSeedPhrase()
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
}
