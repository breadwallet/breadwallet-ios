// 
//  PaymentPathTests.swift
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

class PaymentPathTests : XCTestCase {
    
    func testPaymentPathInit() {
        XCTAssertNotNil(PaymentPath(address: "GiveDirectly$payid.charity"))
        XCTAssertNotNil(PaymentPath(address: "test5$payid.test.coinselect.com"))
        XCTAssertNotNil(PaymentPath(address: "reza$payid.test.coinselect.com"))
        XCTAssertNotNil(PaymentPath(address: "pay$wietse.com"))
        XCTAssertNotNil(PaymentPath(address: "john.smith$dev.payid.es"))
        XCTAssertNotNil(PaymentPath(address: "pay$zochow.ski"))
        
        XCTAssertNil(PaymentPath(address: ""))
        XCTAssertNil(PaymentPath(address: "test5payid.test.coinselect.com"))
        XCTAssertNil(PaymentPath(address: "payid.test.coinselect.com"))
        XCTAssertNil(PaymentPath(address: "rAPERVgXZavGgiGv6xBgtiZurirW2yAmY"))
        XCTAssertNil(PaymentPath(address: "unknown"))
        XCTAssertNil(PaymentPath(address: "0x2c4d5626b6559927350db12e50143e2e8b1b9951"))
    }
    
    func testFetchAddress() {
        let path = PaymentPath(address: "GiveDirectly$payid.charity")
        XCTAssertNotNil(path)
        let exp = expectation(description: "Fetch PayId address")
        path?.fetchAddress(forCurrency: TestCurrencies.btc) { address in
            XCTAssertNotNil(address)
            exp.fulfill()
        }
        let exp2 = expectation(description: "Fetch PayId address")
        path?.fetchAddress(forCurrency: TestCurrencies.eth) { address in
            XCTAssertNotNil(address)
            exp2.fulfill()
        }
        let exp3 = expectation(description: "Fetch PayId address")
        path?.fetchAddress(forCurrency: TestCurrencies.xrp) { address in
            XCTAssertNotNil(address)
            exp3.fulfill()
        }
        waitForExpectations(timeout: 60, handler: nil)
    }
    
    func testFetchAddress2() {
        let path = PaymentPath(address: "reza$payid.test.coinselect.com")
        XCTAssertNotNil(path)
        let exp = expectation(description: "Fetch PayId address2")
        path?.fetchAddress(forCurrency: TestCurrencies.btc) { address in
            XCTAssertNil(address)
            exp.fulfill()
        }
        let exp2 = expectation(description: "Fetch PayId address2")
        path?.fetchAddress(forCurrency: TestCurrencies.xrp) { address in
            XCTAssertNotNil(address)
            exp2.fulfill()
        }
        waitForExpectations(timeout: 60, handler: nil)
    }
    
    func testFetchAddress3() {
        let path = PaymentPath(address: "pay$zochow.ski")
        XCTAssertNotNil(path)
        let exp = expectation(description: "Fetch PayId address3")
        path?.fetchAddress(forCurrency: TestCurrencies.btc) { address in
            XCTAssertNotNil(address)
            exp.fulfill()
        }
        let exp2 = expectation(description: "Fetch PayId address3")
        path?.fetchAddress(forCurrency: TestCurrencies.eth) { address in
            XCTAssertNotNil(address)
            exp2.fulfill()
        }
        let exp3 = expectation(description: "Fetch PayId address3")
        path?.fetchAddress(forCurrency: TestCurrencies.xrp) { address in
            XCTAssertNotNil(address)
            exp3.fulfill()
        }
        let exp4 = expectation(description: "Fetch PayId address3")
        path?.fetchAddress(forCurrency: TestCurrencies.bch) { address in
            XCTAssertNil(address)
            exp4.fulfill()
        }
        waitForExpectations(timeout: 60, handler: nil)
    }
}

//GiveDirectly$payid.charity
//GiveDirectly is a Charity participating in the May 7th  demos: https://www.givedirectly.org/.
//Addresses: BTC, ETH, and XRP mainnet and XRP testnet
//
//test5$payid.test.coinselect.com
//Coinfield is an exchange participating in the demos on May 7th: coinfield.com
//Addresses: XRP Testnet
//
//reza$payid.test.coinselect.com
//This is the CTO of coinfield Reza Bashash
//Addresses: XRP mainnet
//
//pay$wietse.com
//Wietse is an xrp developer leading XRPL Labs and will participate in the May 7th demos.
//Addresses: XRP mainnet and testnet
//
//john.smith$dev.payid.es
//Javi's test server
//Addresses: XRP mainnet.
//
//pay$zochow.ski
//Michael, our Head of Product's PayID
//Addresses: XRP Mainnet, XRP Testnet, BTC Mainnet, ETH mainnet
