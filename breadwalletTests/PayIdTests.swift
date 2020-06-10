// 
//  PayIdTests.swift
//  breadwalletTests
//
//  Created by Adrian Corscadden on 2020-04-28.
//  Copyright © 2020 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import Foundation
import XCTest
@testable import breadwallet

class PayIdTests : XCTestCase {
    
    func testPaymentPathInit() {
        XCTAssertNotNil(PayId(address: "GiveDirectly$payid.charity"))
        XCTAssertNotNil(PayId(address: "test5$payid.test.coinselect.com"))
        XCTAssertNotNil(PayId(address: "reza$payid.test.coinselect.com"))
        XCTAssertNotNil(PayId(address: "pay$wietse.com"))
        XCTAssertNotNil(PayId(address: "john.smith$dev.payid.es"))
        XCTAssertNotNil(PayId(address: "pay$zochow.ski"))
        
        XCTAssertNil(PayId(address: ""))
        XCTAssertNil(PayId(address: "test5payid.test.coinselect.com"))
        XCTAssertNil(PayId(address: "payid.test.coinselect.com"))
        XCTAssertNil(PayId(address: "rAPERVgXZavGgiGv6xBgtiZurirW2yAmY"))
        XCTAssertNil(PayId(address: "unknown"))
        XCTAssertNil(PayId(address: "0x2c4d5626b6559927350db12e50143e2e8b1b9951"))
        XCTAssertNil(PayId(address: "$payid.charity"))
        XCTAssertNil(PayId(address: "payid.charity$"))
    }
    
    func testBTC() {
        let path = PayId(address: "adrian$stage2.breadwallet.com/payid/")
        XCTAssertNotNil(path)
        let exp = expectation(description: "Fetch PayId address")
        path?.fetchAddress(forCurrency: TestCurrencies.btc) { result in
            self.handleResult(result, expected: "mzVtspCQoEGnEbCUWVrug72yD4ShDTUbw8")
            exp.fulfill()
        }
        waitForExpectations(timeout: 60, handler: nil)
    }
    
    func testEth() {
        let path = PayId(address: "adrian$stage2.breadwallet.com/payid/")
        XCTAssertNotNil(path)
        let exp = expectation(description: "Fetch PayId address")
        path?.fetchAddress(forCurrency: TestCurrencies.eth) { result in
            self.handleResult(result, expected: "0x8fB4CB96F7C15F9C39B3854595733F728E1963Bc")
            exp.fulfill()
        }
        waitForExpectations(timeout: 60, handler: nil)
    }
    
    func testUnsuportedCurrency() {
        let path = PayId(address: "adrian$stage2.breadwallet.com/payid/")
        XCTAssertNotNil(path)
        let exp = expectation(description: "Fetch PayId address")
        path?.fetchAddress(forCurrency: TestCurrencies.bch) { address in
            switch address {
            case .success(_):
                XCTFail("BCH should not return a payID")
            case .failure(let error):
                XCTAssert(error == .currencyNotSupported, "Should return currency not supported error")
            }
            exp.fulfill()
        }
        waitForExpectations(timeout: 60, handler: nil)
    }
    
    func handleResult(_ result: Result<String, PayIdError>, expected: String) {
        switch result {
        case .success(let address):
            XCTAssertTrue(address == expected)
        case .failure(let error):
            XCTFail("message: \(error)")
        }
    }

}
