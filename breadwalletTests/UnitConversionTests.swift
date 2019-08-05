//
//  UnitConversionTests.swift
//  breadwalletTests
//
//  Created by Ehsan Rezaie on 2018-03-14.
//  Copyright © 2018-2019 Breadwinner AG. All rights reserved.
//

import XCTest
@testable import breadwallet

class UnitConversionTests : XCTestCase {
    
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
