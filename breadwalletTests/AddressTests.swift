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
    
    func testXRPAddresses() {
        //Valid
        XCTAssertTrue(TestCurrencies.xrp.isValidAddress("rAPERVgXZavGgiGv6xBgtiZurirW2yAmY"))
        //Invalid
        XCTAssertFalse(TestCurrencies.xrp.isValidAddress("unknown"))
        XCTAssertFalse(TestCurrencies.xrp.isValidAddress("blah"))
        XCTAssertFalse(TestCurrencies.xrp.isValidAddress(""))
    }

    func testBTCAddresses() {
        //Valid
        XCTAssertTrue(TestCurrencies.btc.isValidAddress("1Hz96kJKF2HLPGY15JWLB5m9qGNxvt8tHJ"))
        //Invalid
        XCTAssertFalse(TestCurrencies.btc.isValidAddress("blah"))
        XCTAssertFalse(TestCurrencies.btc.isValidAddress(""))
    }
    
    func testBCHAddresses() {
        //Valid
        XCTAssertTrue(TestCurrencies.bch.isValidAddress("qr4kq3eggjd675wej2fqvq9hmzquxz6k4cfn2kmye5"))
        //Invalid
        XCTAssertFalse(TestCurrencies.bch.isValidAddress("blah"))
        XCTAssertFalse(TestCurrencies.bch.isValidAddress(""))
    }
    
    func testEthAddresses() {
        //Valid
        XCTAssertTrue(TestCurrencies.eth.isValidAddress("0x2c4d5626b6559927350db12e50143e2e8b1b9951"))
        //Invalid
        XCTAssertFalse(TestCurrencies.eth.isValidAddress("blah"))
        XCTAssertFalse(TestCurrencies.eth.isValidAddress(""))
    }
    
}
