//
//  BRUserAgentHeaderGeneratorTests.swift
//  breadwalletTests
//
//  Created by Ray Vander Veen on 2019-01-16.
//  Copyright © 2019 Breadwinner AG. All rights reserved.
//

import XCTest

class BRUserAgentHeaderGeneratorTests: XCTestCase {

    func testAppVersions() {
        XCTAssertTrue(BRUserAgentHeaderGenerator.appVersionString(with: ("3", "7", "1", "390")) == "3071390")
        XCTAssertTrue(BRUserAgentHeaderGenerator.appVersionString(with: ("3", "7", "0", "1")) == "3070001")
        XCTAssertTrue(BRUserAgentHeaderGenerator.appVersionString(with: ("3", "10", "0", "1")) == "3100001")
        XCTAssertTrue(BRUserAgentHeaderGenerator.appVersionString(with: ("3", "7", "0", "13")) == "3070013")
        XCTAssertTrue(BRUserAgentHeaderGenerator.appVersionString(with: ("3", "0", "0", "15")) == "3000015")
    }
    
    func testFullUserAgentHeader() {
        let expected = "breadwallet/3071390 CFNetwork/1.2.0 Darwin/18.2.0"
        XCTAssertTrue(BRUserAgentHeaderGenerator.userAgentHeaderString(appName: "breadwallet",
                                                                       appVersion: "3071390",
                                                                       darwinVersion: "Darwin/18.2.0",
                                                                       cfNetworkVersion: "CFNetwork/1.2.0") == expected)
    }
}
