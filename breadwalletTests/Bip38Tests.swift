//
//  Bip38Tests.swift
//  breadwalletTests
//
//  Created by Adrian Corscadden on 2019-03-20.
//  Copyright © 2019 Breadwinner AG. All rights reserved.
//

import XCTest

@testable import breadwallet
import BRCrypto

class Bip38Tests: XCTestCase {

    func testEmpty() {
        let key = Key.createFromString(asPrivate: "", withPassphrase: "")
        XCTAssertNil(key)
    }
    
    func testWrongPassword() {
        let key = Key.createFromString(asPrivate: "6PRW5o9FLp4gJDDVqJQKJFTpMvdsSGJxMYHtHaQBF3ooa8mwD69bapcDQn", withPassphrase: "foobar")
        XCTAssertNil(key)
    }
    
    func testNonECMultipliedUncompressed() {
        let key = Key.createFromString(asPrivate: "6PRVWUbkzzsbcVac2qwfssoUJAN1Xhrg6bNk8J7Nzm5H7kxEbn2Nh2ZoGg", withPassphrase: "TestingOneTwoThree")
        XCTAssertNotNil(key)
        XCTAssertEqual(key?.encodeAsPrivate, "5KN7MzqK5wt2TP1fQCYyHBtDrXdJuXbUzm4A9rKAteGu3Qi5CVR")
    }
    
    func testNonECMultipliedCompressed() {
        let key = Key.createFromString(asPrivate: "6PYNKZ1EAgYgmQfmNVamxyXVWHzK5s6DGhwP4J5o44cvXdoY7sRzhtpUeo", withPassphrase: "TestingOneTwoThree")
        XCTAssertNotNil(key)
        XCTAssertEqual(key?.encodeAsPrivate, "L44B5gGEpqEDRS9vVPz7QT35jcBG2r3CZwSwQ4fCewXAhAhqGVpP")
    }
    
    func testECMultipliedUncompressesNoLot() {
        let key = Key.createFromString(asPrivate: "6PfQu77ygVyJLZjfvMLyhLMQbYnu5uguoJJ4kMCLqWwPEdfpwANVS76gTX", withPassphrase: "TestingOneTwoThree")
        XCTAssertNotNil(key)
        XCTAssertEqual(key?.encodeAsPrivate, "5K4caxezwjGCGfnoPTZ8tMcJBLB7Jvyjv4xxeacadhq8nLisLR2")
    }
    
    func testECMultipliedUncompressedWithLot() {
        let key = Key.createFromString(asPrivate: "6PgNBNNzDkKdhkT6uJntUXwwzQV8Rr2tZcbkDcuC9DZRsS6AtHts4Ypo1j", withPassphrase: "MOLON LABE")
        XCTAssertNotNil(key)
        XCTAssertEqual(key?.encodeAsPrivate, "5JLdxTtcTHcfYcmJsNVy1v2PMDx432JPoYcBTVVRHpPaxUrdtf8")
    }
}
