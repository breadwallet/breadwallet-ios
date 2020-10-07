// 
//  FioTests.swift
//  breadwalletTests
//
//  Created by Adrian Corscadden on 2020-09-29.
//  Copyright © 2020 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import Foundation
import XCTest
@testable import breadwallet

class FioTests : XCTestCase {
    
    func testValidAddress() {
        let fio = ResolvableFactory.resolver("luke@stokes")
        XCTAssertNotNil(fio)
    }
    
    func testInvalidFioAddress() {
        XCTAssertNil(ResolvableFactory.resolver(""))
        XCTAssertNil(ResolvableFactory.resolver("@"))
        XCTAssertNil(ResolvableFactory.resolver("notanaddress"))
    }
    
    func testFetchBTCAddress() {
        let exp = expectation(description: "fetch fio address")
        let fio = ResolvableFactory.resolver("luke@stokes")
        XCTAssertNotNil(fio)
        fio?.fetchAddress(forCurrency: TestCurrencies.btc) { result in
            switch result {
            case .success((let address, _)):
                XCTAssertTrue(TestCurrencies.btc.isValidAddress(address))
            case .failure(_):
                XCTFail()
            }
            exp.fulfill()
        }
        
        wait(for: [exp], timeout: 10.0)
    }
    
    func testFetchEthAddress() {
        let exp = expectation(description: "fetch fio address")
        let fio = ResolvableFactory.resolver("luke@stokes")
        XCTAssertNotNil(fio)
        fio?.fetchAddress(forCurrency: TestCurrencies.eth) { result in
            switch result {
            case .success((let address, _)):
                XCTAssertTrue(TestCurrencies.eth.isValidAddress(address))
            case .failure(_):
                XCTFail()
            }
            exp.fulfill()
        }
        
        wait(for: [exp], timeout: 10.0)
    }
    
    func testFetchBRDAddress() {
        let exp = expectation(description: "fetch fio address")
        let fio = ResolvableFactory.resolver("luke@stokes")
        XCTAssertNotNil(fio)
        fio?.fetchAddress(forCurrency: TestCurrencies.brd) { result in
            switch result {
            case .success(_):
                XCTFail() //currency not supported
            case .failure(let error):
                if case .currencyNotSupported = error {
                    XCTAssert(true)
                } else {
                    XCTFail()
                }
            }
            exp.fulfill()
        }
        
        wait(for: [exp], timeout: 10.0)
    }
    
    func testFetchXRPWithDTAddress() {
        let exp = expectation(description: "fetch fio address")
        let fio = ResolvableFactory.resolver("ericbutz@bitmaxfio")
        XCTAssertNotNil(fio)
        fio?.fetchAddress(forCurrency: TestCurrencies.xrp) { result in
            switch result {
            case .success((let address, let destinationTag)):
                XCTAssertTrue(TestCurrencies.xrp.isValidAddress(address))
                XCTAssertTrue(destinationTag != nil)
            case .failure(_):
                XCTFail()
            }
            exp.fulfill()
        }
        
        wait(for: [exp], timeout: 10.0)
    }
}
