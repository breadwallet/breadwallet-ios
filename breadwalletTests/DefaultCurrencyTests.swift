//
//  DefaultCurrencyTests.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-04-06.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
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
        XCTAssertTrue(localCurrency == UserDefaults.defaultCurrency, "Default currency should be equal to the local currency by default")
    }

    func testUpdate() {
        UserDefaults.defaultCurrency = "EUR"
        XCTAssertTrue(UserDefaults.defaultCurrency == "EUR", "Default currency should update.")
    }

    func testAction() {
        UserDefaults.defaultCurrency = "USD"
        let store = Store()
        store.perform(action: DefaultCurrency.setDefault("CAD"))
        XCTAssertTrue(UserDefaults.defaultCurrency == "CAD", "Actions should persist new value")
    }
    
}
