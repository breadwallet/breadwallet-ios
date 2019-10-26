//
//  PhraseTests.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-02-26.
//  Copyright © 2017-2019 Breadwinner AG. All rights reserved.
//

import XCTest
@testable import breadwallet

class PhraseTests: XCTestCase {

    private var keyStore: KeyStore!

    override func setUp() {
        keyStore = try! KeyStore.create()
    }

    override func tearDown() {
        keyStore.destroy()
    }

    func testEmptyPhrase() {
        XCTAssertFalse(keyStore.isSeedPhraseValid(""), "Empty phrase should not be valid")
    }

    func testInvalidPhrase() {
        XCTAssertFalse(keyStore.isSeedPhraseValid("This is totally and absolutely an invalid bip 39 bread recovery phrase"), "Invalid phrase should not be valid")
    }

    func testValidPhrase() {
        XCTAssertTrue(keyStore.isSeedPhraseValid("kind butter gasp around unfair tape again suit else example toast orphan"), "Valid phrase should be valid.")
    }

    func testFrenchPhrase() {
        XCTAssertTrue(keyStore.isSeedPhraseValid("épidémie bison départ ignorer juriste admirer urticant octupler flocon grappin alvéole chagrin"), "Valid phrase should be valid.")
    }

    func testFrenchWord() {
        XCTAssertTrue(keyStore.isSeedWordValid("épidémie"), "Valid word should be valid.")
    }

    func testValidWord() {
        XCTAssertTrue(keyStore.isSeedWordValid("kind"), "Valid word should be valid.")
    }

    func testInValidWord() {
        XCTAssertFalse(keyStore.isSeedWordValid("blasdf;ljk"), "Invalid word should not be valid.")
    }

    func testEmptyWord() {
        XCTAssertFalse(keyStore.isSeedWordValid(""), "Empty string should not be valid")
    }
}
