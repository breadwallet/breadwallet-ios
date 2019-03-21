//
//  Bip38Tests.swift
//  breadwalletTests
//
//  Created by Adrian Corscadden on 2019-03-20.
//  Copyright © 2019 breadwallet LLC. All rights reserved.
//

import XCTest

@testable import breadwallet
@testable import BRCore

//Ported from test.c in breadwallet-core

class Bip38Tests: XCTestCase {

    func testEmpty() {
        let key = BRKey(bip38Key: "", passphrase: "")
        XCTAssertNil(key)
    }
    
    func testWrongPassword() {
        let key = BRKey(bip38Key: "6PRW5o9FLp4gJDDVqJQKJFTpMvdsSGJxMYHtHaQBF3ooa8mwD69bapcDQn", passphrase: "foobar")
        XCTAssertNil(key)
    }
    
    func testNonECMultipliedUncompressed() {
        var key = BRKey(bip38Key: "6PRVWUbkzzsbcVac2qwfssoUJAN1Xhrg6bNk8J7Nzm5H7kxEbn2Nh2ZoGg", passphrase: "TestingOneTwoThree")
        XCTAssertNotNil(key)
        XCTAssert(key?.privKey() == "5KN7MzqK5wt2TP1fQCYyHBtDrXdJuXbUzm4A9rKAteGu3Qi5CVR\0")
    }
    
    func testNonECMultipliedCompressed() {
        var key = BRKey(bip38Key: "6PYNKZ1EAgYgmQfmNVamxyXVWHzK5s6DGhwP4J5o44cvXdoY7sRzhtpUeo", passphrase: "TestingOneTwoThree")
        XCTAssertNotNil(key)
        XCTAssert(key?.privKey() == "L44B5gGEpqEDRS9vVPz7QT35jcBG2r3CZwSwQ4fCewXAhAhqGVpP\0")
    }
    
    func testECMultipliesUncompressesNoLot() {
        var key = BRKey(bip38Key: "6PfQu77ygVyJLZjfvMLyhLMQbYnu5uguoJJ4kMCLqWwPEdfpwANVS76gTX", passphrase: "TestingOneTwoThree")
        XCTAssertNotNil(key)
        XCTAssert(key?.privKey() == "5K4caxezwjGCGfnoPTZ8tMcJBLB7Jvyjv4xxeacadhq8nLisLR2\0")
    }
    
    func testECMultipliedUncompressedWithLot() {
        var key = BRKey(bip38Key: "6PgNBNNzDkKdhkT6uJntUXwwzQV8Rr2tZcbkDcuC9DZRsS6AtHts4Ypo1j", passphrase: "MOLON LABE")
        XCTAssertNotNil(key)
        XCTAssert(key?.privKey() == "5JLdxTtcTHcfYcmJsNVy1v2PMDx432JPoYcBTVVRHpPaxUrdtf8\0")
    }
    
}
