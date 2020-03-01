// 
//  AddressTests.swift
//  breadwalletTests
//
//  Created by Adrian Corscadden on 2020-02-28.
//  Copyright © 2020 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import Foundation
import XCTest
@testable import breadwallet

class AddressTests : XCTestCase {
    func testRegularXRP() {
        let address = "rAPERVgXZavGgiGv6xBgtiZurirW2yAmY"
        XCTAssertTrue(TestCurrencies.xrp.isValidAddress(address))
    }

    func testUnknownXRP() {
        let address = "unknown"
        XCTAssertFalse(TestCurrencies.xrp.isValidAddress(address))
    }

    func testInvalidAddress() {
        let address = "blah"
        XCTAssertFalse(TestCurrencies.xrp.isValidAddress(address))
    }
    
}
