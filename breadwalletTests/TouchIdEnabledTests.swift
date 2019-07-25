//
//  TouchIdEnabledTests.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-04-04.
//  Copyright © 2017-2019 Breadwinner AG. All rights reserved.
//

import XCTest
@testable import breadwallet

class TouchIdEnabledTests : XCTestCase {

    override func setUp() {
        UserDefaults.standard.removeObject(forKey: "istouchidenabled")
        UserDefaults.standard.removeObject(forKey: "isbiometricsenabledtx")
    }

    func testUserDefaultsStorage() {
        XCTAssertFalse(UserDefaults.isBiometricsEnabled, "Default value is false")
        UserDefaults.isBiometricsEnabled = true
        XCTAssertTrue(UserDefaults.isBiometricsEnabled, "Should be true after being set to true")
        UserDefaults.isBiometricsEnabled = false
        XCTAssertFalse(UserDefaults.isBiometricsEnabled, "Should be false after being set to false")
    }

    func testInitialState() {
        UserDefaults.isBiometricsEnabled = true
        let state = State.initial
        XCTAssertTrue(state.isBiometricsEnabled, "Initial state should be same as stored value")

        UserDefaults.isBiometricsEnabled = false
        let state2 = State.initial
        XCTAssertFalse(state2.isBiometricsEnabled, "Initial state should be same as stored value")
    }

    func testTouchIdAction() {
        UserDefaults.isBiometricsEnabled = true
        Store.perform(action: Biometrics.SetIsEnabledForUnlocking(false))
        XCTAssertFalse(UserDefaults.isBiometricsEnabled, "Actions should persist new value")
    }
    
    func testTouchIdActionForSending() {
        UserDefaults.isBiometricsEnabledForTransactions = true
        Store.perform(action: Biometrics.SetIsEnabledForTransactions(false))
        XCTAssertFalse(UserDefaults.isBiometricsEnabledForTransactions, "Actions should persist new value")
    }

}
