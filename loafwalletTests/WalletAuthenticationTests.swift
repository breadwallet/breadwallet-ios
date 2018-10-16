//
//  WalletLockingTests.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-02-17.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import XCTest
@testable import breadwallet

class WalletAuthenticationTests : XCTestCase {

    private let walletManager: WalletManager = try! WalletManager(store: Store(), dbPath: nil)
    private let pin = "123456"

    override func setUp() {
        super.setUp()
        clearKeychain()
        guard walletManager.noWallet else { XCTFail("Wallet should not exist"); return }
        guard walletManager.setRandomSeedPhrase() != nil else { XCTFail("Phrase should not be nil"); return }
    }

    override func tearDown() {
        super.tearDown()
        clearKeychain()
    }

    func testAuthentication() {
        XCTAssert(walletManager.forceSetPin(newPin: pin), "Setting PIN should succeed")
        XCTAssert(walletManager.authenticate(pin: pin), "Authentication should succeed.")
    }

    func testWalletDisabledUntil() {
        XCTAssert(walletManager.forceSetPin(newPin: pin), "Setting PIN should succeed")

        //Perform 2 wrong pin attempts
        XCTAssertFalse(walletManager.authenticate(pin: "654321"), "Authentication with wrong PIN should fail.")
        XCTAssertFalse(walletManager.authenticate(pin: "839405"), "Authentication with wrong PIN should fail.")
        XCTAssert(walletManager.walletDisabledUntil == 0, "Wallet should not be disabled after 2 wrong pin attempts")

        //Perform another wrong attempt that should disable the wallet
        XCTAssertFalse(walletManager.authenticate(pin: "127345"), "Authentication with wrong PIN should fail.")
        let disabledUntil = walletManager.walletDisabledUntil
        XCTAssert(disabledUntil > Date().timeIntervalSince1970, "Wallet should be disabled until some time in the future. DisabledUntil: \(disabledUntil)")
    }

    func testWalletDisabledTwice() {
        XCTAssert(walletManager.forceSetPin(newPin: pin), "Setting PIN should succeed")

        //Lock wallet
        XCTAssertFalse(walletManager.authenticate(pin: "654322"), "Authentication with wrong PIN should fail.")
        XCTAssertFalse(walletManager.authenticate(pin: "839408"), "Authentication with wrong PIN should fail.")
        XCTAssertFalse(walletManager.authenticate(pin: "127346"), "Authentication with wrong PIN should fail.")

        let disabledUntil = walletManager.walletDisabledUntil
        XCTAssert(disabledUntil > Date().timeIntervalSince1970, "Wallet should be disabled until some time in the future. DisabledUntil: \(disabledUntil)")
    }

    func testWalletNotDisabled() {
        XCTAssert(walletManager.forceSetPin(newPin: pin), "Setting PIN should succeed")
        XCTAssert(walletManager.walletDisabledUntil == 0, "Wallet should not be disabled after pin has been set")
    }
}
