//
//  DataExtensionTests.swift
//  breadwalletTests
//
//  Created by Ehsan Rezaie on 2019-05-17.
//  Copyright © 2019 breadwallet LLC. All rights reserved.
//

import XCTest
@testable import breadwallet
@testable import BRCore

class DataExtensionTests: XCTestCase {

    func testDataConstructors() {
        XCTAssertTrue(Data(hexString: "0xD224cA0c819e8E97ba0136B3b95ceFf503B79f53")?.base64EncodedString() == "0iTKDIGejpe6ATazuVzv9QO3n1M=")
        XCTAssertTrue(Data(hexString: "0123456789ABCDEF")?.base64EncodedString() == "ASNFZ4mrze8=")
        XCTAssertTrue(Data(hexString: "Not a hex string") == nil)

        // testing legacy hash -> UInt256 -> Data compatibility
        // since UInt256 is little-endian it results in Data with bytes in reverse
        let hash = "0xe468eddbd2aa5e601c9c8424743e54445dd8d7a4691a30e3fa88fc3e55f330e8"
        var hashAsUInt256 = UInt256(hexString: hash)
        let dataConvertedFromUInt256: Data = withUnsafePointer(to: &hashAsUInt256) { p in
            return Data(bytes: p, count: MemoryLayout<UInt256>.stride)
        }
        let dataConvertedFromHex = Data(hexString: hash, reversed: true)
        XCTAssertEqual(dataConvertedFromUInt256, dataConvertedFromHex)
        XCTAssertEqual(dataConvertedFromUInt256.sha256, dataConvertedFromHex?.sha256)
    }

    func testTxMetadataKeyDerivation() {
        let testHashesAndKeys = [
            // BTC
            "0eb6c6869037f287210f66a2ed0e8a97b08681150635bd392b64375552aa3bd8": "eec747f96a48ce8a992f2fa00d5b33381dda699b2edf4e25caa88157608caa8f",
            // ETH
            "0xc0844b68e885d2d6e887083bd9a21002f93fccf0560abdc417964554949634e3": "28645a4e6a2e34b8b21fa23ec3b12e8ee31522c768eb0881777ca6b013a0d61a",
            "0xa4d022e35a4b0f4687535a8a82e540dad91adccbfb5695df4af316df001931c4": "a0885746df4a231f7a15f0dfbe5b4c5a529460be0f7808ea71c02a92cff293c7",
        ]

        for (hash, expectedKey) in testHashesAndKeys {
            let data = Data(hexString: hash, reversed: true)
            let derivedKey = data?.sha256.hexString

            XCTAssertNotNil(derivedKey)
            XCTAssertEqual(derivedKey, expectedKey)
        }
    }

}
