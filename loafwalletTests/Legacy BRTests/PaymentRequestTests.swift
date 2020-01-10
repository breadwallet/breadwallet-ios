//
//  PaymentRequestTests.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-03-26.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import XCTest
@testable import loafwallet

class PaymentRequestTests : XCTestCase {

    func testEmptyString() {
        XCTAssertNil(PaymentRequest(string: ""))
    }

    func testInvalidAddress() {
        XCTAssertNil(PaymentRequest(string: "notandaddress"), "Payment request should be nil for invalid addresses")
    }

    func testBasicExample() {
        let uri = "litecoin:LPnVRGLWT21mw5ZVkNL7o8BuyNuyTsGtdT"
        let request = PaymentRequest(string: uri)
        XCTAssertNotNil(request)
        XCTAssertTrue(request?.toAddress == "LPnVRGLWT21mw5ZVkNL7o8BuyNuyTsGtdT")
    }

    func testAmountInUri() {
        let uri = "litecoin:LPnVRGLWT21mw5ZVkNL7o8BuyNuyTsGtdT?amount=1.2"
        let request = PaymentRequest(string: uri)
        XCTAssertNotNil(request)
        XCTAssertTrue(request?.toAddress == "LPnVRGLWT21mw5ZVkNL7o8BuyNuyTsGtdT")
        XCTAssertTrue(request?.amount?.rawValue == 120000000)
    }

    func testRequestMetaData() {
        let uri = "litecoin:LPnVRGLWT21mw5ZVkNL7o8BuyNuyTsGtdT?amount=1.2&message=Payment&label=Satoshi"
        let request = PaymentRequest(string: uri)
        XCTAssertTrue(request?.toAddress == "LPnVRGLWT21mw5ZVkNL7o8BuyNuyTsGtdT")
        XCTAssertTrue(request?.amount?.rawValue == 120000000)
        XCTAssertTrue(request?.message == "Payment")
        XCTAssertTrue(request?.label == "Satoshi")
    }

    func testExtraEqualSign() {
        let uri = "litecoin:LPnVRGLWT21mw5ZVkNL7o8BuyNuyTsGtdT?amount=1.2&message=Payment=true&label=Satoshi"
        let request = PaymentRequest(string: uri)
        XCTAssertTrue(request?.message == "Payment=true")
    }

    func testMessageWithSpace() {
        let uri = "litecoin:LPnVRGLWT21mw5ZVkNL7o8BuyNuyTsGtdT?amount=1.2&message=Payment message test&label=Satoshi"
        let request = PaymentRequest(string: uri)
        XCTAssertTrue(request?.message == "Payment message test")
    }

//    func testPaymentProtocol() {
//        let uri = "https://www.syndicoin.co/signednoroot.paymentrequest"
//        let rBottom layout guide is deprecated since iOS 11.0 [7]equest = PaymentRequest(string: uri)
//        XCTAssertTrue(request?.type == .remote)
//
//        let promise = expectation(description: "Fetch Request")
//        request?.fetchRemoteRequest(completion: { newRequest in
//
//            XCTAssertNotNil(newRequest)
//            promise.fulfill()
//        })
//
//        waitForExpectations(timeout: 5.0) { error in
//            XCTAssertNil(error)
//        }
//    }
}

