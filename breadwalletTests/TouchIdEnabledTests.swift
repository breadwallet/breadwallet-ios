//
//  TouchIdEnabledTests.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-04-04.
//  Copyright © 2017-2019 Breadwinner AG. All rights reserved.
//

import XCTest
@testable import breadwallet

//
// Tests enabling/disabling of biometrics authentication settings.
//
class TouchIdEnabledTests : XCTestCase {

    private var keyStore: KeyStore!
    
    override func setUp() {
        super.setUp()
        clearKeychain()
        keyStore = try! KeyStore.create()
    }
    
    override func tearDown() {
        super.tearDown()
        clearKeychain()
        keyStore.destroy()
    }

    func testSetGet() {
        // initial state
        XCTAssertFalse(self.keyStore.isBiometricsEnabledForUnlocking)
        XCTAssertFalse(self.keyStore.isBiometricsEnabledForTransactions)
        
        // set to true
        self.keyStore.isBiometricsEnabledForUnlocking = true
        XCTAssertTrue(self.keyStore.isBiometricsEnabledForUnlocking)
        
        self.keyStore.isBiometricsEnabledForTransactions = true
        XCTAssertTrue(self.keyStore.isBiometricsEnabledForTransactions)
        
        // set to false
        self.keyStore.isBiometricsEnabledForUnlocking = false
        XCTAssertFalse(self.keyStore.isBiometricsEnabledForUnlocking)
        
        self.keyStore.isBiometricsEnabledForTransactions = false
        XCTAssertFalse(self.keyStore.isBiometricsEnabledForTransactions)
    }
    
    // Tests the upgrade from storing biometrics authentication settings in UserDefaults to
    // storing them in the KeyStore.
    func testUpgradePath() {
    
        // If the UserDefaults setting for unlocking the device is true, this setting
        // should migrate to the KeyStore.
        UserDefaults.standard.set(true, forKey: "istouchidenabled")
        
        // Test the migration.
        XCTAssertTrue(self.keyStore.isBiometricsEnabledForUnlocking)
        
        // Verify that the legacy UserDefaults setting is disabled now so that it's a one-time upgrade path check.
        XCTAssertFalse(UserDefaults.isBiometricsEnabled)
    }
}
