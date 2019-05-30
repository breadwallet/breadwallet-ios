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
        XCTAssertEqual(UInt256(string: "1.", decimals: 8), UInt256(100000000))
        XCTAssertEqual(UInt256(string: "1.23456789", decimals: 8), UInt256(123456789))
        
        // ETH -> Wei
        XCTAssertEqual(UInt256(string: "1.", decimals: 18), UInt256(1000000000000000000))
        XCTAssertEqual(UInt256(string: "1.0", decimals: 18), UInt256(1000000000000000000))
        XCTAssertEqual(UInt256(string: "0.000000000000000001", decimals: 18), UInt256(1))
        XCTAssertEqual(UInt256(string: "1.2345678", decimals: 18), UInt256(1234567800000000000))
        XCTAssertEqual(UInt256(string: "1234567.891", decimals: 18), UInt256(hexString: "0x1056E0F39C37A5C9B8000"))
        XCTAssertEqual(UInt256(string: "1.234567891234567891", decimals: 18), UInt256(1234567891234567891))
        
        //TODO: test overflow, underflow, strange inputs
    }
    
    func testAmount() {
        let highP = "1.123456789987654321"
        let rate = Rate(code: "USD", name: "USD", rate: 1000.0, reciprocalCode: "BTC")
        
        XCTAssertEqual(Amount.zero(Currencies.btc, rate: rate).fiatDescription, "$0.00")
        XCTAssertEqual(Amount.zero(Currencies.btc, rate: rate).tokenDescription, "0 BTC")
        XCTAssertEqual(Amount(tokenString: "1", currency: Currencies.btc, unit: Currencies.btc.baseUnit, rate: rate).fiatDescription, "$0.01")
        XCTAssertEqual(Amount(tokenString: "1", currency: Currencies.btc, unit: Currencies.btc.baseUnit, rate: rate).tokenDescription, "0.00000001 BTC")
        XCTAssertEqual(Amount(tokenString: "1", currency: Currencies.eth, unit: Currencies.eth.baseUnit, rate: rate).tokenDescription, "0.000000000000000001 ETH")
        XCTAssertEqual(Amount(tokenString: highP, currency: Currencies.eth, rate: rate, maximumFractionDigits: 5).tokenDescription, "1.12346 ETH")
        XCTAssertEqual(Amount(tokenString: highP, currency: Currencies.eth, rate: rate, maximumFractionDigits: 8).tokenDescription, "1.12345679 ETH")
        XCTAssertEqual(Amount(tokenString: highP, currency: Currencies.eth, rate: rate, maximumFractionDigits: 8).fiatDescription, "$1,123.46")

        let oneETHinWEI = "1000000000000000000"

        XCTAssertEqual(Amount(tokenString: "1", currency: Currencies.eth).tokenUnformattedString(in: Currencies.eth.baseUnit), oneETHinWEI)
        XCTAssertEqual(Amount(tokenString: "1.0", currency: Currencies.eth).tokenUnformattedString(in: Currencies.eth.baseUnit), oneETHinWEI)
        XCTAssertEqual(Amount(tokenString: "0.000000000000000001", currency: Currencies.eth).tokenUnformattedString(in: Currencies.eth.baseUnit), "1")
        XCTAssertEqual(Amount(tokenString: "1.2345678", currency: Currencies.eth).tokenUnformattedString(in: Currencies.eth.baseUnit), "1234567800000000000")
        XCTAssertEqual(Amount(tokenString: "1,234,567.891", currency: Currencies.eth).tokenUnformattedString(in: Currencies.eth.baseUnit), "1234567891000000000000000")
        XCTAssertEqual(Amount(tokenString: "1.234567891234567891", currency: Currencies.eth).tokenUnformattedString(in: Currencies.eth.baseUnit), "1234567891234567891")

        XCTAssertEqual(Amount(tokenString: "0.000011", currency: Currencies.eth, unit: Currencies.eth.defaultUnit, rate: rate).tokenDescription, "0.00001 ETH") // default max digits is 5
        XCTAssertEqual(Amount(tokenString: "0.0000011", currency: Currencies.eth, unit: Currencies.eth.defaultUnit, rate: rate).tokenDescription, "0.0000011 ETH") // tests override default max digits
        
        let french = Locale(identifier: "fr_FR")
        XCTAssertEqual(Amount(tokenString: "1,0", currency: Currencies.eth, locale: french).tokenUnformattedString(in: Currencies.eth.baseUnit), "1000000000000000000")
        XCTAssertEqual(Amount(tokenString: "0,000000000000000001", currency: Currencies.eth, locale: french).tokenUnformattedString(in: Currencies.eth.baseUnit), "1")
        XCTAssertEqual(Amount(tokenString: "1,2345678", currency: Currencies.eth, locale: french).tokenUnformattedString(in: Currencies.eth.baseUnit), "1234567800000000000")
        XCTAssertEqual(Amount(tokenString: "1 234 567,891", currency: Currencies.eth, locale: french).tokenUnformattedString(in: Currencies.eth.baseUnit), "1234567891000000000000000")
        XCTAssertEqual(Amount(tokenString: "1,234567891234567891", currency: Currencies.eth, locale: french).tokenUnformattedString(in: Currencies.eth.baseUnit), "1234567891234567891")

        // input uses the specified locale (parameter is only used for tests), output uses the system locale (assume en_US)
        XCTAssertEqual(Amount(tokenString: "0,000011", currency: Currencies.eth, locale: french, unit: Currencies.eth.defaultUnit, rate: rate).tokenDescription, "0.00001 ETH") // default max digits is 5
        XCTAssertEqual(Amount(tokenString: "0,0000011", currency: Currencies.eth, locale: french, unit: Currencies.eth.defaultUnit, rate: rate).tokenDescription, "0.0000011 ETH") // tests override default max digits
        
        let portugese = Locale(identifier: "pt_BR")
        XCTAssertEqual(Amount(tokenString: "1,0", currency: Currencies.eth, locale: portugese).tokenUnformattedString(in: Currencies.eth.baseUnit), "1000000000000000000")
        XCTAssertEqual(Amount(tokenString: "0,000000000000000001", currency: Currencies.eth, locale: portugese).tokenUnformattedString(in: Currencies.eth.baseUnit), "1")
        XCTAssertEqual(Amount(tokenString: "1,2345678", currency: Currencies.eth, locale: portugese).tokenUnformattedString(in: Currencies.eth.baseUnit), "1234567800000000000")
        XCTAssertEqual(Amount(tokenString: "1.234.567,891", currency: Currencies.eth, locale: portugese).tokenUnformattedString(in: Currencies.eth.baseUnit), "1234567891000000000000000")
        XCTAssertEqual(Amount(tokenString: "1,234567891234567891", currency: Currencies.eth, locale: portugese).tokenUnformattedString(in: Currencies.eth.baseUnit), "1234567891234567891")

        XCTAssertEqual(Amount(tokenString: "0,000011", currency: Currencies.eth, locale: portugese, unit: Currencies.eth.defaultUnit, rate: rate).tokenDescription, "0.00001 ETH") // default max digits is 5
        XCTAssertEqual(Amount(tokenString: "0,0000011", currency: Currencies.eth, locale: portugese, unit: Currencies.eth.defaultUnit, rate: rate).tokenDescription, "0.0000011 ETH") // tests override default max digits
        
        XCTAssertEqual(Amount(fiatString: "0.01", currency: Currencies.btc, rate: rate)?.tokenUnformattedString(in: Currencies.btc.baseUnit), "1000")
        XCTAssertEqual(Amount(fiatString: ".0001", currency: Currencies.btc, rate: rate)?.tokenUnformattedString(in: Currencies.btc.baseUnit), "10")
        XCTAssertEqual(Amount(fiatString: "100001.9999", currency: Currencies.btc, rate: rate)?.tokenUnformattedString(in: Currencies.btc.baseUnit), "10000199990")
    }
}
