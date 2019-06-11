//
//  BRAPIClientTests.swift
//  breadwallet
//
//  Created by Samuel Sutch on 12/7/16.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import XCTest
@testable import breadwallet
import BRCore

class FakeAuthenticator: WalletAuthenticator {
    var secret: UInt256
    let key: BRKey
    var userAccount: [AnyHashable: Any]? = nil

    init() {
        var keyData = Data(count: 32)
        let count = keyData.count
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

    // not used
    
    var creationTime: TimeInterval { return C.bip39CreationTime }

    var masterPubKey: BRMasterPubKey? { return nil }
    var ethPubKey: BRKey? { return nil }

    var pinLoginRequired: Bool { return false }
    var pinLength: Int { assertionFailure(); return 0 }

    var walletDisabledUntil: TimeInterval { return TimeInterval() }

    func authenticate(withPin: String) -> Bool {
        assertionFailure()
        return false
    }

    func authenticate(withPhrase: String) -> Bool {
        assertionFailure()
        return false
    }

    func authenticate(withBiometricsPrompt: String, completion: @escaping (BiometricsResult) -> Void) {
        assertionFailure()
        completion(.failure)
    }

    func buildBitIdKey(url: String, index: Int) -> BRKey? {
        assertionFailure()
        return nil
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
        let key = client.authKey!.publicKey.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> BRKey in
            var k = BRKey()
            BRKeySetPubKey(&k, ptr.baseAddress!.assumingMemoryBound(to: UInt8.self), client.authKey!.publicKey.count)
            return k
        }
        XCTAssertEqual(pubKey1, key.publicKey.base58) // the key decoded from our encoded key is the same
    }
    
    func testHandshake() {
        // test that we can get a token and access /me
        // TODO revert this back to /me from /me/features when /me is back up and running
        let req = URLRequest(url: client.url("/me/features"))
        let exp = expectation(description: "auth")
        client.dataTaskWithRequest(req, authenticated: true, retryCount: 0) { (data, resp, err) in
            XCTAssertEqual(resp?.statusCode, 200)
            exp.fulfill()
        }.resume()
        waitForExpectations(timeout: 30, handler: nil)
    }
}
