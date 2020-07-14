// 
//  CoinGeckoTests.swift
//  breadwalletTests
//
//  Created by Adrian Corscadden on 2020-07-14.
//  Copyright © 2020 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import Foundation
import XCTest
@testable import breadwallet
import CoinGecko

class CoinGeckoTests : XCTestCase {
    
    private let fiatCurrencies = FiatCurrency.availableCurrencies
    private let client = CoinGeckoClient()
    
    func testSupported() {
        let exp = expectation(description: "Fetch supported currencies")
        let supported = Resources.supported { (result: Result<[String], CoinGeckoError>) in
            guard case .success(let supported) = result else { XCTFail("Coingecko supported should succeed"); exp.fulfill(); return }
            var missingCodes = [String]()
            self.fiatCurrencies.forEach {
                if !supported.contains($0.code.lowercased()) {
                    missingCodes.append($0.code)
                }
            }
            XCTAssert(missingCodes.isEmpty, "Missing codes should be empty but contained: \(missingCodes)")
            exp.fulfill()
        }
        client.load(supported)
        waitForExpectations(timeout: 60, handler: nil)
    }
    
}
