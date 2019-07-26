//
//  BitIdTests.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-06-01.
//  Copyright © 2017-2019 Breadwinner AG. All rights reserved.
//

import XCTest
@testable import breadwallet

class BitIdTests : XCTestCase {

    private var keyStore: KeyStore!

    override func setUp() {
        super.setUp()
        clearKeychain()
        keyStore = try! KeyStore.create()
        guard keyStore.noWallet else { XCTFail("Wallet should not exist"); return }
        guard keyStore.setSeedPhrase("famous gesture ladder armor must taste afraid search stove panda grab deer") != nil else { XCTFail("Setting seed should work"); return  }
    }

    override func tearDown() {
        super.tearDown()
        clearKeychain()
        keyStore.destroy()
    }

    //TODO:AUTH
//    func testBitIdResponse() {
//        let url = URL(string: "bitid://bitid.bitcoin.blue/callback?x=f98f5e62d82b7086&u=1")!
//        let response = walletManager.buildBitIdResponse(stringToSign: url.absoluteString,
//                                                        url: url.host!,
//                                                        index: 0)
//        XCTAssert(response.0 == 200, "Resonse should be 200")
//        if let json = response.1, let address = json["address"] as? String, let signature = json["signature"] as? String  {
//            XCTAssertTrue(address == "189kGtkhuNeDXTjFVwZfkPEudmiotXAjJV")
//            XCTAssertTrue(signature == "IJM81VPGm0A5LUnVEuojMFJzH3lbArizBt4BqUzkz3OmZ9/7zi/8vvc8CA12G10raOKoeFnIet1Jz11h4U3Wc6w=")
//        } else {
//            XCTAssert(false, "Json should not be nil")
//        }
//
//    }

}
