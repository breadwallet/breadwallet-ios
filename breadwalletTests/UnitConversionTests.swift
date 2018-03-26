//
//  UnitConversionTests.swift
//  breadwalletTests
//
//  Created by Ehsan Rezaie on 2018-03-14.
//  Copyright © 2018 breadwallet LLC. All rights reserved.
//

import XCTest
@testable import breadwallet
@testable import BRCore

class UnitConversionTests : XCTestCase {
    
    func testUInt256Comparison() {
        XCTAssertEqual(UInt256(0), UInt256(0))
        XCTAssertNotEqual(UInt256(0), UInt256(1))
        XCTAssertEqual(UInt256(0x0102030405060708), UInt256(72623859790382856))
        XCTAssertLessThan(UInt256(100), UInt256(200))
        XCTAssertGreaterThan(UInt256(0xff), UInt256(0xaa))
    }
    
    func testUInt256ToString() {
        let sample = UInt256(string: "123456789ABCDEFEDCBA98765432123456789ABCDEF", radix: 16)
        // Radix = 10
        XCTAssertEqual(String(UInt256()), "0")
        XCTAssertEqual(String(UInt256(1)), "1")
        XCTAssertEqual(String(UInt256(100)), "100")
        XCTAssertEqual(String(UInt256(255)), "255")
        XCTAssertEqual(String(UInt256(12345)), "12345")
        XCTAssertEqual(String(UInt256(123456789)), "123456789")
        XCTAssertEqual(String(sample), "425693205796080237694414176550132631862392541400559")
        
        // Radix = 16
        XCTAssertEqual(String(UInt256(), radix: 16), "0")
        XCTAssertEqual(String(UInt256(1), radix: 16), "1")
        XCTAssertEqual(String(UInt256(255), radix: 16), "ff")
        XCTAssertEqual(String(UInt256(0x1001), radix: 16), "1001")
        XCTAssertEqual(String(UInt256(0x0102030405060708), radix: 16), "102030405060708")
        XCTAssertEqual(String(sample, radix: 16), "123456789abcdefedcba98765432123456789abcdef")
        
        // Satoshis -> BTC
        XCTAssertEqual("1.23456789", UInt256(123456789).string(decimals: 8))
        
        // Wei -> ETH
        XCTAssertEqual("1.234567891234567891", UInt256(1234567891234567891).string(decimals: 18))
        
    }
    
    func testStringToUInt256() {
        var hex = UInt256(hexString: "0x0")
        var base10 = UInt256(string: "0", radix: 10)
        var actual = UInt256(0)
        XCTAssertEqual(hex, actual)
        XCTAssertEqual(base10, actual)
        
        hex = UInt256(hexString: "0x01")
        base10 = UInt256(string: "1", radix: 10)
        actual = UInt256(1)
        XCTAssertEqual(hex, actual)
        XCTAssertEqual(base10, actual)
        
        hex = UInt256(hexString: "0xff")
        base10 = UInt256(string: "255", radix: 10)
        actual = UInt256(255)
        XCTAssertEqual(hex, actual)
        XCTAssertEqual(base10, actual)
        
        // BTC -> Satoshis
        XCTAssertEqual(UInt256(string: "1", decimals: 8), UInt256(100000000))
        XCTAssertEqual(UInt256(string: "1.23456789", decimals: 8), UInt256(123456789))
        
        // ETH -> Wei
        XCTAssertEqual(UInt256(string: "1", decimals: 18), UInt256(1000000000000000000))
        XCTAssertEqual(UInt256(string: "1.0", decimals: 18), UInt256(1000000000000000000))
        XCTAssertEqual(UInt256(string: "1.23456", decimals: 18), UInt256(123456))
        XCTAssertEqual(UInt256(string: "1.2345678", decimals: 18), UInt256(12345678))
        XCTAssertEqual(UInt256(string: "1.234567891234567891", decimals: 18), UInt256(1234567891234567891))
    }
}
