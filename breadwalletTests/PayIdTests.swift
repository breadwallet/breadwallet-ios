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
        assertIsPayId(address: "GiveDirectly$payid.charity")
        assertIsPayId(address: "test5$payid.test.coinselect.com")
        assertIsPayId(address: "reza$payid.test.coinselect.com")
        assertIsPayId(address: "pay$wietse.com")
        assertIsPayId(address: "john.smith$dev.payid.es")
        assertIsPayId(address: "pay$zochow.ski")
        
        XCTAssertNil(ResolvableFactory.resolver(""))
        XCTAssertNil(ResolvableFactory.resolver("test5payid.test.coinselect.com"))
        XCTAssertNil(ResolvableFactory.resolver("payid.test.coinselect.com"))
        XCTAssertNil(ResolvableFactory.resolver("rAPERVgXZavGgiGv6xBgtiZurirW2yAmY"))
        XCTAssertNil(ResolvableFactory.resolver("unknown"))
        XCTAssertNil(ResolvableFactory.resolver("0x2c4d5626b6559927350db12e50143e2e8b1b9951"))
        XCTAssertNil(ResolvableFactory.resolver("$payid.charity"))
        XCTAssertNil(ResolvableFactory.resolver("payid.charity$"))
    }
    
    func assertIsPayId(address: String) {
        let payID = ResolvableFactory.resolver(address)
        XCTAssertNotNil(payID, "Resolver should not be nil for \(address)")
        XCTAssertTrue(payID!.type == .payId, "Resolver should not be type Payid for \(address)")
    }

    func testBTC() {
        let path = ResolvableFactory.resolver("adrian$stage2.breadwallet.com/payid/")
        XCTAssertNotNil(path)
        let exp = expectation(description: "Fetch PayId address")
        path?.fetchAddress(forCurrency: TestCurrencies.btc) { result in
            self.handleResult(result, expected: "mzVtspCQoEGnEbCUWVrug72yD4ShDTUbw8")
            exp.fulfill()
        }
        waitForExpectations(timeout: 60, handler: nil)
    }

    func testEth() {
        let path = ResolvableFactory.resolver("adrian$stage2.breadwallet.com/payid/")
        XCTAssertNotNil(path)
        let exp = expectation(description: "Fetch PayId address")
        path?.fetchAddress(forCurrency: TestCurrencies.eth) { result in
            self.handleResult(result, expected: "0x8fB4CB96F7C15F9C39B3854595733F728E1963Bc")
            exp.fulfill()
        }
        waitForExpectations(timeout: 60, handler: nil)
    }

    func testUnsuportedCurrency() {
        let path = ResolvableFactory.resolver("adrian$stage2.breadwallet.com/payid/")
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

    func handleResult(_ result: Result<(String, String?), ResolvableError>, expected: String) {
        switch result {
        case .success(let address):
            XCTAssertTrue(address.0 == expected)
        case .failure(let error):
            XCTFail("message: \(error)")
        }
    }

}
