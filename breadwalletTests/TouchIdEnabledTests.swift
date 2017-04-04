//
//  TouchIdEnabledTests.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-04-04.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import XCTest
@testable import breadwallet

class TouchIdEnabledTests : XCTestCase {

    override func setUp() {
        UserDefaults.standard.removeObject(forKey: "istouchidenabled")
    }

    func testUserDefaultsStorage() {
        XCTAssertFalse(UserDefaults.isTouchIdEnabled, "Default value is false")
        UserDefaults.isTouchIdEnabled = true
        XCTAssertTrue(UserDefaults.isTouchIdEnabled, "Should be true after being set to true")
        UserDefaults.isTouchIdEnabled = false
        XCTAssertFalse(UserDefaults.isTouchIdEnabled, "Should be false after being set to false")
    }

    func testInitialState() {
        UserDefaults.isTouchIdEnabled = true
        let state = State.initial
        XCTAssertTrue(state.isTouchIdEnabled, "Initial state should be same as stored value")

        UserDefaults.isTouchIdEnabled = false
        let state2 = State.initial
        XCTAssertFalse(state2.isTouchIdEnabled, "Initial state should be same as stored value")
    }

    func testTouchIdAction() {
        UserDefaults.isTouchIdEnabled = true
        let store = Store()
        store.perform(action: TouchId.setIsEnabled(false))
        XCTAssertFalse(UserDefaults.isTouchIdEnabled, "Actions should persist new value")
    }

}
