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
    
    func testAmountStringConversion() {
        let highP = "1.123456789987654321"
        let rate = Rate(code: "USD", name: "USD", rate: 1000.0, reciprocalCode: "BTC")
        
        XCTAssertEqual(Amount.zero(TestCurrencies.btc, rate: rate).fiatDescription, "$0.00")
        XCTAssertEqual(Amount.zero(TestCurrencies.btc, rate: rate).tokenDescription, "0 BTC")
        XCTAssertEqual(Amount(tokenString: "1", currency: TestCurrencies.btc, unit: TestCurrencies.btc.baseUnit, rate: rate).fiatDescription, "$0.01")
        XCTAssertEqual(Amount(tokenString: "1", currency: TestCurrencies.btc, unit: TestCurrencies.btc.baseUnit, rate: rate).tokenDescription, "0.00000001 BTC")
        XCTAssertEqual(Amount(tokenString: "1", currency: TestCurrencies.eth, unit: TestCurrencies.eth.baseUnit, rate: rate).tokenDescription, "0.000000000000000001 ETH")
        XCTAssertEqual(Amount(tokenString: highP, currency: TestCurrencies.eth, rate: rate, maximumFractionDigits: 5).tokenDescription, "1.12346 ETH")
        XCTAssertEqual(Amount(tokenString: highP, currency: TestCurrencies.eth, rate: rate, maximumFractionDigits: 8).tokenDescription, "1.12345679 ETH")
        XCTAssertEqual(Amount(tokenString: highP, currency: TestCurrencies.eth, rate: rate, maximumFractionDigits: 8).fiatDescription, "$1,123.46")

        let oneETHinWEI = "1000000000000000000"

        XCTAssertEqual(Amount(tokenString: "1", currency: TestCurrencies.eth).tokenUnformattedString(in: TestCurrencies.eth.baseUnit), oneETHinWEI)
        XCTAssertEqual(Amount(tokenString: "1.0", currency: TestCurrencies.eth).tokenUnformattedString(in: TestCurrencies.eth.baseUnit), oneETHinWEI)
        XCTAssertEqual(Amount(tokenString: "0.000000000000000001", currency: TestCurrencies.eth).tokenUnformattedString(in: TestCurrencies.eth.baseUnit), "1")
        XCTAssertEqual(Amount(tokenString: "1.2345678", currency: TestCurrencies.eth).tokenUnformattedString(in: TestCurrencies.eth.baseUnit), "1234567800000000000")
        XCTAssertEqual(Amount(tokenString: "1,234,567.891", currency: TestCurrencies.eth).tokenUnformattedString(in: TestCurrencies.eth.baseUnit), "1234567891000000000000000")
        XCTAssertEqual(Amount(tokenString: "1.234567891234567891", currency: TestCurrencies.eth).tokenUnformattedString(in: TestCurrencies.eth.baseUnit), "1234567891234567891")

        XCTAssertEqual(Amount(tokenString: "0.000011", currency: TestCurrencies.eth, unit: TestCurrencies.eth.defaultUnit, rate: rate).tokenDescription, "0.00001 ETH") // default max digits is 5
        XCTAssertEqual(Amount(tokenString: "0.0000011", currency: TestCurrencies.eth, unit: TestCurrencies.eth.defaultUnit, rate: rate).tokenDescription, "0.0000011 ETH") // tests override default max digits
        
        XCTAssertEqual(Amount(fiatString: "0.01", currency: TestCurrencies.btc, rate: rate)?.tokenUnformattedString(in: TestCurrencies.btc.baseUnit), "1000")
        XCTAssertEqual(Amount(fiatString: ".0001", currency: TestCurrencies.btc, rate: rate)?.tokenUnformattedString(in: TestCurrencies.btc.baseUnit), "10")
        XCTAssertEqual(Amount(fiatString: "100001.9999", currency: TestCurrencies.btc, rate: rate)?.tokenUnformattedString(in: TestCurrencies.btc.baseUnit), "10000199990")
    }
    
    func testAmountFromLocalizedString() {
        let rate = Rate(code: "USD", name: "USD", rate: 100.0, reciprocalCode: "ETH")
        
        let french = Locale(identifier: "fr_FR")
        let groupingSeparator = french.groupingSeparator! // special whitespace character on iOS 13
        XCTAssertEqual(Amount(tokenString: "1,0", currency: TestCurrencies.eth, locale: french).tokenUnformattedString(in: TestCurrencies.eth.baseUnit), "1000000000000000000")
        XCTAssertEqual(Amount(tokenString: "0,000000000000000001", currency: TestCurrencies.eth, locale: french).tokenUnformattedString(in: TestCurrencies.eth.baseUnit), "1")
        XCTAssertEqual(Amount(tokenString: "1,2345678", currency: TestCurrencies.eth, locale: french).tokenUnformattedString(in: TestCurrencies.eth.baseUnit), "1234567800000000000")
        XCTAssertEqual(Amount(tokenString: "1\(groupingSeparator)234\(groupingSeparator)567,891", currency: TestCurrencies.eth, locale: french).tokenUnformattedString(in: TestCurrencies.eth.baseUnit), "1234567891000000000000000")
        XCTAssertEqual(Amount(tokenString: "1,234567891234567891", currency: TestCurrencies.eth, locale: french).tokenUnformattedString(in: TestCurrencies.eth.baseUnit), "1234567891234567891")

        // input uses the specified locale (parameter is only used for tests), output uses the system locale (assume en_US)
        XCTAssertEqual(Amount(tokenString: "0,000011", currency: TestCurrencies.eth, locale: french, unit: TestCurrencies.eth.defaultUnit, rate: rate).tokenDescription, "0.00001 ETH") // default max digits is 5
        XCTAssertEqual(Amount(tokenString: "0,0000011", currency: TestCurrencies.eth, locale: french, unit: TestCurrencies.eth.defaultUnit, rate: rate).tokenDescription, "0.0000011 ETH") // tests override default max digits
        
        let portugese = Locale(identifier: "pt_BR")
        XCTAssertEqual(Amount(tokenString: "1,0", currency: TestCurrencies.eth, locale: portugese).tokenUnformattedString(in: TestCurrencies.eth.baseUnit), "1000000000000000000")
        XCTAssertEqual(Amount(tokenString: "0,000000000000000001", currency: TestCurrencies.eth, locale: portugese).tokenUnformattedString(in: TestCurrencies.eth.baseUnit), "1")
        XCTAssertEqual(Amount(tokenString: "1,2345678", currency: TestCurrencies.eth, locale: portugese).tokenUnformattedString(in: TestCurrencies.eth.baseUnit), "1234567800000000000")
        XCTAssertEqual(Amount(tokenString: "1.234.567,891", currency: TestCurrencies.eth, locale: portugese).tokenUnformattedString(in: TestCurrencies.eth.baseUnit), "1234567891000000000000000")
        XCTAssertEqual(Amount(tokenString: "1,234567891234567891", currency: TestCurrencies.eth, locale: portugese).tokenUnformattedString(in: TestCurrencies.eth.baseUnit), "1234567891234567891")

        XCTAssertEqual(Amount(tokenString: "0,000011", currency: TestCurrencies.eth, locale: portugese, unit: TestCurrencies.eth.defaultUnit, rate: rate).tokenDescription, "0.00001 ETH") // default max digits is 5
        XCTAssertEqual(Amount(tokenString: "0,0000011", currency: TestCurrencies.eth, locale: portugese, unit: TestCurrencies.eth.defaultUnit, rate: rate).tokenDescription, "0.0000011 ETH") // tests override default max digits
    }
    
    func testAmountToValue() {
        let rate = Rate(code: "USD", name: "USD", rate: 100.0, reciprocalCode: "ETH")
        var amount = Amount(tokenString: "1.2345678",
                            currency: TestCurrencies.eth,
                            rate: rate,
                            maximumFractionDigits: Int(TestCurrencies.eth.defaultUnit.decimals))
        let decimalValue = Decimal(string: "1.2345678")
        let fiatValue = Decimal(string: "123.45678")
        
        amount.locale = Locale.current
        XCTAssertEqual(amount.tokenValue, decimalValue)
        XCTAssertEqual(amount.fiatValue, fiatValue)
        
        amount.locale = Locale(identifier: "fr_FR")
        XCTAssertEqual(amount.tokenValue, decimalValue)
        XCTAssertEqual(amount.fiatValue, fiatValue)
        
        amount.locale = Locale(identifier: "pt_BR")
        XCTAssertEqual(amount.tokenValue, decimalValue)
        XCTAssertEqual(amount.fiatValue, fiatValue)
        
        amount.locale = Locale(identifier: "fr_CH") // different separators for currencies and decimal numbers
        XCTAssertEqual(amount.tokenValue, decimalValue)
        XCTAssertEqual(amount.fiatValue, fiatValue)
        
        amount.locale = Locale(identifier: "he_IL")
        XCTAssertEqual(amount.tokenValue, decimalValue)
        XCTAssertEqual(amount.fiatValue, fiatValue)
        
        // precision loss from Double conversion is expected
        amount = Amount(tokenString: "1.234567891234567891", currency: TestCurrencies.eth, rate: rate)
        XCTAssertEqual(amount.tokenValue, Decimal(string: "1.23456789123457"))
        XCTAssertEqual(amount.fiatValue, Decimal(string: "123.456789123457"))
    }
    
    func testEthAmountWithBaseUnits() {
        let rate = Rate(code: "USD", name: "USD", rate: 200.0, reciprocalCode: "ETH")
        let a = Amount(tokenString: "123000000000000000000", currency: TestCurrencies.eth, unit: TestCurrencies.eth.baseUnit, rate: rate)
        XCTAssertNotNil(a)
        let format = NumberFormatter()
        format.numberStyle = .currency
        format.generatesDecimalNumbers = false
        format.currencyCode = ""
        format.currencySymbol = ""
        format.maximumFractionDigits = 0
        XCTAssertEqual("123,000,000,000,000,000,000",
                       a.cryptoAmount.string(as: TestCurrencies.eth.baseUnit, formatter: format) ?? "")
    }
}
