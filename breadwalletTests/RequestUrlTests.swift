// 
//  RequestUrlTests.swift
//  breadwalletTests
//
//  Created by Adrian Corscadden on 2019-10-06.
//  Copyright © 2019 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import XCTest
@testable import breadwallet

class RequestUrlTests : XCTestCase {

    //MARK: Without Amounts
    func testBTCLegacyUri() {
        let address = "12A1MyfXbW6RhdRAZEqofac5jCQQjwEPBu"
        let uri = TestCurrencies.btc.addressURI(address)
        XCTAssertNotNil(uri)
        XCTAssertEqual(uri, "bitcoin:12A1MyfXbW6RhdRAZEqofac5jCQQjwEPBu")
    }
    
    func testBTCSegwitUri() {
        let address = "bc1qgu4y0m03kerspt2vzgr8aysplxvuasrxpyejer"
        let uri = TestCurrencies.btc.addressURI(address)
        XCTAssertNotNil(uri)
        XCTAssertEqual(uri, "bitcoin:bc1qgu4y0m03kerspt2vzgr8aysplxvuasrxpyejer")
    }
    
    func testBCHUri() {
        let address = "qr2g8fyjy0csdujuxcg02syrp5eaqgtn9ytlk3650u"
        let uri = TestCurrencies.bch.addressURI(address)
        XCTAssertNotNil(uri)
        XCTAssertEqual(uri, "bitcoincash:qr2g8fyjy0csdujuxcg02syrp5eaqgtn9ytlk3650u")
    }
    
    func testEthUri() {
        let address = "0xbDFdAd139440D2Db9BA2aa3B7081C2dE39291508"
        let uri = TestCurrencies.eth.addressURI(address)
        XCTAssertNotNil(uri)
        XCTAssertEqual(uri, "ethereum:0xbDFdAd139440D2Db9BA2aa3B7081C2dE39291508")
    }
    
    func testTokenUri() {
        let address = "0xbDFdAd139440D2Db9BA2aa3B7081C2dE39291508"
        let uri = TestCurrencies.brd.addressURI(address)
        XCTAssertNotNil(uri)
        XCTAssertEqual(uri, "ethereum:0xbDFdAd139440D2Db9BA2aa3B7081C2dE39291508?tokenaddress=0x558ec3152e2eb2174905cd19aea4e34a23de9ad6")
    }
    
    //MARK: With Amounts
    func testBTCLegacyUriWithAmount() {
        let address = "12A1MyfXbW6RhdRAZEqofac5jCQQjwEPBu"
        let amount = Amount(tokenString: "1", currency: TestCurrencies.btc)
        let uri = PaymentRequest.requestString(withAddress: address, forAmount: amount)
        XCTAssertNotNil(uri)
        XCTAssertEqual(uri, "bitcoin:12A1MyfXbW6RhdRAZEqofac5jCQQjwEPBu?amount=1")
    }
    
    func testBTCSegwitUriWithAmount() {
        let address = "bc1qgu4y0m03kerspt2vzgr8aysplxvuasrxpyejer"
        let amount = Amount(tokenString: "1", currency: TestCurrencies.btc)
        let uri = PaymentRequest.requestString(withAddress: address, forAmount: amount)
        XCTAssertNotNil(uri)
        XCTAssertEqual(uri, "bitcoin:bc1qgu4y0m03kerspt2vzgr8aysplxvuasrxpyejer?amount=1")
    }
    
    func testBCHUriWithAmount() {
        let address = "qr2g8fyjy0csdujuxcg02syrp5eaqgtn9ytlk3650u"
        let amount = Amount(tokenString: "1", currency: TestCurrencies.bch)
        let uri = PaymentRequest.requestString(withAddress: address, forAmount: amount)
        XCTAssertNotNil(uri)
        XCTAssertEqual(uri, "bitcoincash:qr2g8fyjy0csdujuxcg02syrp5eaqgtn9ytlk3650u?amount=1")
    }
    
    func testEthUriWithAmount() {
        let address = "0xbDFdAd139440D2Db9BA2aa3B7081C2dE39291508"
        let amount = Amount(tokenString: "1", currency: TestCurrencies.eth)
        let uri = PaymentRequest.requestString(withAddress: address, forAmount: amount)
        XCTAssertNotNil(uri)
        XCTAssertEqual(uri, "ethereum:0xbDFdAd139440D2Db9BA2aa3B7081C2dE39291508?amount=1")
    }
    
    func testTokenUriWithAmount() {
        let address = "0xbDFdAd139440D2Db9BA2aa3B7081C2dE39291508"
        let amount = Amount(tokenString: "1", currency: TestCurrencies.brd)
        let uri = PaymentRequest.requestString(withAddress: address, forAmount: amount)
        XCTAssertNotNil(uri)
        XCTAssertEqual(uri, "ethereum:0xbDFdAd139440D2Db9BA2aa3B7081C2dE39291508?tokenaddress=0x558ec3152e2eb2174905cd19aea4e34a23de9ad6&amount=1")
    }
    
}
