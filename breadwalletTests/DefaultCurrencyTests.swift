//
//  DefaultCurrencyTests.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-04-06.
//  Copyright © 2017-2019 Breadwinner AG. All rights reserved.
//

import XCTest
@testable import breadwallet

class DefaultCurrencyTests : XCTestCase {

    override func setUp() {
        UserDefaults.standard.removeObject(forKey: "defaultcurrency")
    }

    func testInitialValue() {
        guard let localCurrency = Locale.current.currencyCode else {
            XCTFail("We should have a local currency")
            return
        }
        XCTAssertTrue(localCurrency == UserDefaults.defaultCurrencyCode, "Default currency should be equal to the local currency by default")
    }

    func testUpdate() {
        UserDefaults.defaultCurrencyCode = "EUR"
        XCTAssertTrue(UserDefaults.defaultCurrencyCode == "EUR", "Default currency should update.")
    }

    func testAction() {
        UserDefaults.defaultCurrencyCode = "USD"
        Store.perform(action: DefaultCurrency.SetDefault("CAD"))
        XCTAssertTrue(UserDefaults.defaultCurrencyCode == "CAD", "Actions should persist new value")
    }
    
}
