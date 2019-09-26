//
//  DataExtensionTests.swift
//  breadwalletTests
//
//  Created by Ehsan Rezaie on 2019-05-17.
//  Copyright © 2019 Breadwinner AG. All rights reserved.
//

import XCTest
@testable import breadwallet
import BRCrypto

class DataExtensionTests: XCTestCase {

    func testDataConstructors() {
        XCTAssertTrue(Data(hexString: "0xD224cA0c819e8E97ba0136B3b95ceFf503B79f53")?.base64EncodedString() == "0iTKDIGejpe6ATazuVzv9QO3n1M=")
        XCTAssertTrue(Data(hexString: "0123456789ABCDEF")?.base64EncodedString() == "ASNFZ4mrze8=")
        XCTAssertNil(Data(hexString: "Not a hex string"))

        let txhash = "0xe468eddbd2aa5e601c9c8424743e54445dd8d7a4691a30e3fa88fc3e55f330e8"
        let sha256 = "054a113a98262837a64c9bc028302ba4c53167137a906e9e5b0884441680d60d"
        XCTAssertEqual(Data(hexString: txhash)?.sha256,
                       Data(hexString: sha256))
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

    func testEncryption() {
        let privKey = "S6c56bnXQiBjk9mqSYE7ykVQ7NzrRy"
        let key = Key.createFromString(asPrivate: privKey)!
        for i in 0..<20 {
            let plaintext = "plaintext \(i)"
            let encrypted = plaintext.data(using: .utf8)!.chacha20Poly1305AEADEncrypt(key: key)
            let decrypted = try! encrypted.chacha20Poly1305AEADDecrypt(key: key)
            XCTAssert(plaintext == String(data: decrypted, encoding: .utf8))
        }
    }
    
    func testCompactSign() {
        let secrets = ["5HxWvvfubhXpYYpS3tJkw6fq9jE9j18THftkZjHHfmFiWtmAbrj",
                       "5KC4ejrDjv152FGwP386VD1i2NYc5KkfSMyv1nGy1VGDxGHqVY3",
                       "Kwr371tjA9u2rFSMZjTNun2PXXP3WPZu2afRHTcta6KxEUdm1vEw", // compressed
                       "L3Hq7a8FEQwJkW1M2GNKDW28546Vp5miewcCzSqUD9kCAXrJdS3g"] // compressed
        let signatures = ["1c5dbbddda71772d95ce91cd2d14b592cfbc1dd0aabd6a394b6c2d377bbe59d31d14ddda21494a4e221f0824f0b8b924c43fa43c0ad57dccdaa11f81a6bd4582f6",
                          "1c52d8a32079c11e79db95af63bb9600c5b04f21a9ca33dc129c2bfa8ac9dc1cd561d8ae5e0f6c1a16bde3719c64c2fd70e404b6428ab9a69566962e8771b5944d",
                          "205dbbddda71772d95ce91cd2d14b592cfbc1dd0aabd6a394b6c2d377bbe59d31d14ddda21494a4e221f0824f0b8b924c43fa43c0ad57dccdaa11f81a6bd4582f6",
                          "2052d8a32079c11e79db95af63bb9600c5b04f21a9ca33dc129c2bfa8ac9dc1cd561d8ae5e0f6c1a16bde3719c64c2fd70e404b6428ab9a69566962e8771b5944d"
        ]
        
        let message = "Very deterministic message".data(using: .utf8)?.sha256_2
        XCTAssertNotNil(message)
        
        zip(secrets, signatures).forEach { secret, signature in
            let key = Key.createFromString(asPrivate: secret)
            XCTAssertNotNil(key)
            guard let outputSig = CoreSigner.compact.sign(data32: message!, using: key!) else { return XCTFail() }
            print(outputSig.hexString)
            XCTAssert(outputSig.hexString == signature)
        }

    }
    
    func testCompression() {
        for _ in 0..<10 {
            let randomData = (1...7321).map{_ in UInt8(arc4random_uniform(0x30))}
            let data = Data(bytes: UnsafePointer<UInt8>(randomData), count: randomData.count)
            guard let compressed = data.bzCompressedData else {
                XCTFail("compressed data was nil")
                return
            }
            guard let decompressed = Data(bzCompressedData: compressed) else {
                XCTFail("decompressed data was nil")
                return
            }
            XCTAssertEqual(data.hexString, decompressed.hexString)
        }
    }

}
