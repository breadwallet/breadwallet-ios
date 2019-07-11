//
//  WalletCreationTests.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-02-26.
//  Copyright © 2017-2019 Breadwinner AG. All rights reserved.
//

import XCTest
@testable import breadwallet

class WalletCreationTests: XCTestCase {

    private var keyStore: KeyStore!

    override func setUp() {
        super.setUp()
        clearKeychain()
        keyStore = try! KeyStore.create()
    }

    override func tearDown() {
        super.tearDown()
        clearKeychain()
        keyStore.destroy()
    }

    func testWalletCreation() {
        XCTAssertTrue(keyStore.noWallet)
        guard let seed = keyStore.setRandomSeedPhrase() else { return XCTFail("Seed phrase should not be nil.") }
        XCTAssert(keyStore.isSeedPhraseValid(seed))
        let now = Date()
        XCTAssert(now.timeIntervalSince(keyStore.creationTime) < 10, "Invalid wallet creation time") // within 10s margin
        XCTAssertNotNil(keyStore.masterPubKey)
        XCTAssertFalse(keyStore.noWallet)
    }

    func testVerifySeed() {
        let pin = "123456"
        guard let seed = keyStore.setRandomSeedPhrase() else { return XCTFail("Seed phrase should not be nil.") }
        // verify seed
        XCTAssertTrue(keyStore.setPin(pin))
        XCTAssertTrue(keyStore.seedPhrase(pin: pin) == seed)
        XCTAssertNil(keyStore.seedPhrase(pin:"654321"))
    }

    func testWalletRecovery() {
        let pin = "123456"
        let seed = "marine sand egg submit hotel flower taxi accident square lunch certain inmate"
        let invalidSeed = "invalid seed phrase"

        // invalid seed
        XCTAssertTrue(keyStore.noWallet)
        XCTAssertFalse(keyStore.isSeedPhraseValid(invalidSeed))
        XCTAssertFalse(keyStore.setSeedPhrase(invalidSeed))
        XCTAssertTrue(keyStore.noWallet)

        // valid seed
        XCTAssertTrue(keyStore.isSeedPhraseValid(seed))
        XCTAssertTrue(keyStore.setSeedPhrase(seed))
        XCTAssertFalse(keyStore.noWallet, "wallet should exist after recovering from seed phrase")
        XCTAssertTrue(keyStore.setPin(pin))

        // recover with existing wallet
        XCTAssertFalse(keyStore.setSeedPhrase(seed), "setting seed should fail if a wallet exists")
        XCTAssert(keyStore.seedPhrase(pin: pin) == seed)

        // new wallet with existing wallet
        XCTAssertNil(keyStore.setRandomSeedPhrase(), "setting random seed should fail if a wallet exists")
        XCTAssert(keyStore.seedPhrase(pin: pin) == seed)
    }

    func testWipeWallet() {
        let pin = "123456"

        // create wallet
        XCTAssertNotNil(keyStore.setRandomSeedPhrase())
        XCTAssertFalse(keyStore.noWallet)
        XCTAssertTrue(keyStore.setPin(pin))
        XCTAssertTrue(keyStore.authenticate(withPin: pin))

        // wipe wallet
        XCTAssertTrue(keyStore.wipeWallet())

        XCTAssertTrue(keyStore.noWallet)
        XCTAssertNil(keyStore.masterPubKey)
        XCTAssertFalse(keyStore.authenticate(withPin: pin), "authentication should fail after wallet is wiped")
    }
}
