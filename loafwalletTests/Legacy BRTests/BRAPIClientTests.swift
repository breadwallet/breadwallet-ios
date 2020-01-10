//
//  BRAPIClientTests.swift
//  breadwallet
//
//  Created by Samuel Sutch on 12/7/16.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import XCTest
@testable import loafwallet
import BRCore

class FakeAuthenticator: WalletAuthenticator {
    var secret: UInt256
    let key: BRKey
    var userAccount: [AnyHashable: Any]? = nil
    
    init() {
        
        let count = 32 
        var keyData = Data(count: count)
        let result = keyData.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, count, $0)
        }
        if result != errSecSuccess {
            fatalError("couldnt generate random data for key")
        }
        print("base58 encoded secret key data \(keyData.base58)")
        secret = keyData.uInt256
        key = withUnsafePointer(to: &secret, { (secPtr: UnsafePointer<UInt256>) in
            var k = BRKey()
            k.compressed = 1
            BRKeySetSecret(&k, secPtr, 0)
            return k
        })
    }
    
    var noWallet: Bool { return false }
    
    var apiAuthKey: String? {
        var k = key
        k.compressed = 1
        let pkLen = BRKeyPrivKey(&k, nil, 0)
        var pkData = Data(count: pkLen)
        BRKeyPrivKey(&k, pkData.withUnsafeMutableBytes({ $0 }), pkLen)
        return String(data: pkData, encoding: .utf8)
    }
}

// This test will test against the live API at api.breadwallet.com
class BRAPIClientTests: XCTestCase {
    var authenticator: WalletAuthenticator!
    var client: BRAPIClient!
    
    override func setUp() {
        super.setUp()
        authenticator = FakeAuthenticator() // each test will get its own account
        client = BRAPIClient(authenticator: authenticator)
    }
    
    override func tearDown() {
        super.tearDown()
        authenticator = nil
        client = nil
    }
    
    func testPublicKeyEncoding() {
        let pubKey1 = client.authKey!.publicKey.base58
        let b = pubKey1.base58DecodedData()
        let b2 = b.base58
        XCTAssertEqual(pubKey1, b2) // sanity check on our base58 functions
        let key = client.authKey!.publicKey.withUnsafeBytes { (ptr: UnsafePointer<UInt8>) -> BRKey in
            var k = BRKey()
            BRKeySetPubKey(&k, ptr, client.authKey!.publicKey.count)
            return k
        }
        XCTAssertEqual(pubKey1, key.publicKey.base58) // the key decoded from our encoded key is the same
    }
    /*
    func testHandshake() {
        // test that we can get a token and access /me
        let req = URLRequest(url: client.url("/me"))
        let exp = expectation(description: "auth")
        client.dataTaskWithRequest(req, authenticated: true, retryCount: 0) { (data, resp, err) in
            XCTAssertEqual(resp?.statusCode, 200)
            exp.fulfill()
        }.resume()
        waitForExpectations(timeout: 30, handler: nil)
    } */
}
