//
//  PaymentRequestTests.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-03-26.
//  Copyright © 2017-2019 Breadwinner AG. All rights reserved.
//

import XCTest
@testable import breadwallet

class PaymentRequestTests : XCTestCase {

    func testEmptyString() {
        XCTAssertNil(PaymentRequest(string: "", currency: TestCurrencies.btc))
        XCTAssertNil(PaymentRequest(string: "", currency: TestCurrencies.bch))
    }

    func testInvalidAddress() {
        XCTAssertNil(PaymentRequest(string: "notandaddress", currency: TestCurrencies.btc), "Payment request should be nil for invalid addresses")
        XCTAssertNil(PaymentRequest(string: "notandaddress", currency: TestCurrencies.bch), "Payment request should be nil for invalid addresses")
    }

    func testBasicExampleBTC() {
        let uri = "bitcoin:12A1MyfXbW6RhdRAZEqofac5jCQQjwEPBu"
        let request = PaymentRequest(string: uri, currency: TestCurrencies.btc)
        XCTAssertNotNil(request)
        XCTAssertTrue(request?.toAddress?.description == "12A1MyfXbW6RhdRAZEqofac5jCQQjwEPBu")
    }
    
    func testBasicExampleBCH() {
        let uri = "bitcoincash:qr2g8fyjy0csdujuxcg02syrp5eaqgtn9ytlk3650u"
        let request = PaymentRequest(string: uri, currency: TestCurrencies.bch)
        XCTAssertNotNil(request)
        print("address: \(request!.toAddress!.description)")
        XCTAssertTrue(request?.toAddress?.description == "bitcoincash:qr2g8fyjy0csdujuxcg02syrp5eaqgtn9ytlk3650u")
    }

    func testBasicExampleETH() {
        let uri = "ethereum:0xbDFdAd139440D2Db9BA2aa3B7081C2dE39291508"
        let request = PaymentRequest(string: uri, currency: TestCurrencies.eth)
        XCTAssertNotNil(request)
        XCTAssertTrue(request?.toAddress?.description == "0xbDFdAd139440D2Db9BA2aa3B7081C2dE39291508")
    }
    
    func testERC20() {
        let uri = "ethereum:0x558ec3152e2eb2174905cd19aea4e34a23de9ad6/transfer?address=0x9c7C4bd7d9A37d68F5B6C95a475299D55cE09D35"
        let request = PaymentRequest(string: uri, currency: TestCurrencies.brd)
        XCTAssertNotNil(request)
        XCTAssertTrue(request?.toAddress?.description == "0x9c7C4bd7d9A37d68F5B6C95a475299D55cE09D35")
    }

    func testERC20WithAmount() {
        let uri = "ethereum:0x558ec3152e2eb2174905cd19aea4e34a23de9ad6/transfer?address=0x9c7C4bd7d9A37d68F5B6C95a475299D55cE09D35&amount=5"
        let request = PaymentRequest(string: uri, currency: TestCurrencies.brd)
        XCTAssertNotNil(request)
        XCTAssertTrue(request?.toAddress?.description == "0x9c7C4bd7d9A37d68F5B6C95a475299D55cE09D35")
    }

    func testAmountInUriBTC() {
        let uri = "bitcoin:12A1MyfXbW6RhdRAZEqofac5jCQQjwEPBu?amount=1.2"
        let request = PaymentRequest(string: uri, currency: TestCurrencies.btc)
        XCTAssertNotNil(request)
        XCTAssertTrue(request?.toAddress?.description == "12A1MyfXbW6RhdRAZEqofac5jCQQjwEPBu")
        XCTAssertTrue(request?.amount?.tokenUnformattedString(in: TestCurrencies.btc.baseUnit) == "120000000")
    }
    
    func testAmountInUriBCH() {
        let uri = "bitcoincash:qr2g8fyjy0csdujuxcg02syrp5eaqgtn9ytlk3650u?amount=1.2"
        let request = PaymentRequest(string: uri, currency: TestCurrencies.bch)
        XCTAssertNotNil(request)
        XCTAssertTrue(request?.toAddress?.description == "bitcoincash:qr2g8fyjy0csdujuxcg02syrp5eaqgtn9ytlk3650u")
        XCTAssertTrue(request?.amount?.tokenUnformattedString(in: TestCurrencies.btc.baseUnit) == "120000000")
    }

    func testRequestMetaDataBTC() {
        let uri = "bitcoin:12A1MyfXbW6RhdRAZEqofac5jCQQjwEPBu?amount=1.2&message=Payment&label=Satoshi"
        let request = PaymentRequest(string: uri, currency: TestCurrencies.btc)
        XCTAssertTrue(request?.toAddress?.description == "12A1MyfXbW6RhdRAZEqofac5jCQQjwEPBu")
        XCTAssertTrue(request?.amount?.tokenUnformattedString(in: TestCurrencies.btc.baseUnit) == "120000000")
        XCTAssertTrue(request?.message == "Payment")
        XCTAssertTrue(request?.label == "Satoshi")
    }
    
    func testRequestMetaDataBCH() {
        let uri = "bitcoincash:qr2g8fyjy0csdujuxcg02syrp5eaqgtn9ytlk3650u?amount=1.2&message=Payment&label=Satoshi"
        let request = PaymentRequest(string: uri, currency: TestCurrencies.bch)
        XCTAssertTrue(request?.toAddress?.description == "bitcoincash:qr2g8fyjy0csdujuxcg02syrp5eaqgtn9ytlk3650u")
        XCTAssertTrue(request?.amount?.tokenUnformattedString(in: TestCurrencies.btc.baseUnit) == "120000000")
        XCTAssertTrue(request?.message == "Payment")
        XCTAssertTrue(request?.label == "Satoshi")
    }

    func testExtraEqualSign() {
        let uri = "bitcoin:12A1MyfXbW6RhdRAZEqofac5jCQQjwEPBu?amount=1.2&message=Payment=true&label=Satoshi"
        let request = PaymentRequest(string: uri, currency: TestCurrencies.btc)
        XCTAssertTrue(request?.message == "Payment=true")
    }

    func testMessageWithSpace() {
        let uri = "bitcoin:12A1MyfXbW6RhdRAZEqofac5jCQQjwEPBu?amount=1.2&message=Payment message test&label=Satoshi"
        let request = PaymentRequest(string: uri, currency: TestCurrencies.btc)
        XCTAssertTrue(request?.message == "Payment message test")
    }

    func testPaymentProtocol() {
        //TODO:CRYPTO payment requests
//        let uri = "https://www.syndicoin.co/signednoroot.paymentrequest"
//        let request = PaymentRequest(string: uri, currency: Currencies.btc)
//        XCTAssertTrue(request?.type == .remote)
//
//        let promise = expectation(description: "Fetch Request")
//        request?.fetchRemoteRequest(completion: { newRequest in
//            XCTAssertNotNil(newRequest)
//            promise.fulfill()
//        })
//
//        waitForExpectations(timeout: 5.0) { error in
//            XCTAssertNil(error)
//        }
    }
}
