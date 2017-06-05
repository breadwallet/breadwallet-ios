//
//  PhraseTests.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-02-26.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import XCTest
@testable import breadwallet

class PhraseTests: XCTestCase {

    private let walletManager: WalletManager = try! WalletManager(store: Store(), dbPath: nil)

    func testEmptyPhrase() {
        XCTAssertFalse(walletManager.isPhraseValid(""), "Empty phrase should not be valid")
    }

    func testInvalidPhrase() {
        XCTAssertFalse(walletManager.isPhraseValid("This is totally and absolutely an invalid bip 39 bread recovery phrase"), "Invalid phrase should not be valid")
    }

    func testValidPhrase() {
        XCTAssertTrue(walletManager.isPhraseValid("kind butter gasp around unfair tape again suit else example toast orphan"), "Valid phrase should be valid.")
    }

    func testFrenchPhrase() {
        XCTAssertTrue(walletManager.isPhraseValid("épidémie bison départ ignorer juriste admirer urticant octupler flocon grappin alvéole chagrin"), "Valid phrase should be valid.")
    }

    func testFrenchWord() {
        XCTAssertTrue(walletManager.isWordValid("épidémie"), "Valid word should be valid.")
    }

    func testValidWord() {
        XCTAssertTrue(walletManager.isWordValid("kind"), "Valid word should be valid.")
    }

    func testInValidWord() {
        XCTAssertFalse(walletManager.isWordValid("blasdf;ljk"), "Invalid word should not be valid.")
    }

    func testEmptyWord() {
        XCTAssertFalse(walletManager.isWordValid(""), "Empty string should not be valid")
    }
}
