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

    private let walletManager: WalletManager = try! WalletManager(dbPath: nil)
    private let pin = "123456"

    override func setUp() {
        super.setUp()
        clearKeychain()
        guard walletManager.noWallet else { XCTFail("Wallet should not exist"); return }
        guard walletManager.setRandomSeedPhrase() != nil else { XCTFail("Phrase should not be nil"); return }
    }

    func testAuthentication() {
        XCTAssert(walletManager.forceSetPin(newPin: pin), "Setting PIN should succeed")
        XCTAssert(walletManager.authenticate(pin: pin), "Authentication should succeed.")
    }

    private func clearKeychain() {
        let classes = [kSecClassGenericPassword as String,
                       kSecClassInternetPassword as String,
                       kSecClassCertificate as String,
                       kSecClassKey as String,
                       kSecClassIdentity as String]
        classes.forEach { className in
            SecItemDelete([kSecClass as String: className]  as CFDictionary)
        }
    }
}
