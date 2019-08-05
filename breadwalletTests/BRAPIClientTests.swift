//
//  BRAPIClientTests.swift
//  breadwallet
//
//  Created by Samuel Sutch on 12/7/16.
//  Copyright © 2016-2019 Breadwinner AG. All rights reserved.
//

import XCTest
@testable import breadwallet
import BRCrypto

class FakeAuthenticator: WalletAuthenticator {
    
    var apiUserAccount: [AnyHashable : Any]?
    let apiAuthKey: Key?
    var userAccount: [AnyHashable: Any]? = nil

    init() {
        let (phrase, _) = Account.generatePhrase(words: bip39Words)!
        apiAuthKey = Key.createForBIP32ApiAuth(phrase: phrase, words: bip39Words)
    }

    var noWallet: Bool { return false }

    // not used
    
    var creationTime: Date { return Date(timeIntervalSinceReferenceDate: C.bip39CreationTime) }

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

    func loadAccount() -> Result<Account, AccountError> {
        return .failure(.noAccount)
    }
    
    func createAccount(withPin: String) -> Account? {
        return nil
    }
    
    func createAccount(withBiometricsPrompt: String, completion: @escaping (Account?) -> Void) {
        completion(nil)
    }

    func buildBitIdKey(url: String, index: Int) -> Key? {
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
        guard let pubKey1 = client.authKey?.encodeAsPublic.hexToData?.base58 else {
            return XCTFail()
        }
        let b = pubKey1.base58DecodedData()
        XCTAssertNotNil(b)
        let b2 = b!.base58
        XCTAssertEqual(pubKey1, b2) // sanity check on our base58 functions
        let key = Key.createFromString(asPublic: client.authKey!.encodeAsPublic)
        XCTAssertEqual(pubKey1, key?.encodeAsPublic.hexToData?.base58) // the key decoded from our encoded key is the same
    }
    
    func testHandshake() {
        // test that we can get a token and access /me
        let req = URLRequest(url: client.url("/me"))
        let exp = expectation(description: "auth")
        client.dataTaskWithRequest(req, authenticated: true, retryCount: 0) { (data, resp, err) in
            XCTAssertEqual(resp?.statusCode, 200)
            exp.fulfill()
        }.resume()
        waitForExpectations(timeout: 30, handler: nil)
    }
}
