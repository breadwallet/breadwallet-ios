//
//  TouchIdEnabledTests.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-04-04.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import XCTest
@testable import loafwallet

class TouchIdEnabledTests : XCTestCase {

    override func setUp() {
        UserDefaults.standard.removeObject(forKey: "isbiometricsenabled")
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
        let store = Store()
        store.perform(action: Biometrics.setIsEnabled(false))
        XCTAssertFalse(UserDefaults.isBiometricsEnabled, "Actions should persist new value")
    }

}
