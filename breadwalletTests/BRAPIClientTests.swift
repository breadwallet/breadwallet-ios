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

// This test will test against the live API at api.breadwallet.com
class BRAPIClientTests: XCTestCase {
    var authenticator: WalletAuthenticator { return keyStore as WalletAuthenticator }
    var client: BRAPIClient!
    private var keyStore: KeyStore!
    
    override func setUp() {
        super.setUp()
        clearKeychain()
        keyStore = try! KeyStore.create()
        _ = setupNewAccount(keyStore: keyStore) // each test will get its own account
        client = BRAPIClient(authenticator: authenticator)
    }
    
    override func tearDown() {
        super.tearDown()
        client = nil
        clearKeychain()
        keyStore.destroy()
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
    
    func testBlockchainDBAuthentication() {
        let baseUrl = "https://api.blockset.com"
        let authClient = AuthenticationClient(baseURL: URL(string: baseUrl)!,
                                              urlSession: URLSession.shared)

        //let deviceId = UUID().uuidString
        let exp = expectation(description: "auth")

        authenticator.authenticateWithBlockchainDB(client: authClient) { result in
            switch result {
            case .success(let jwt):
                XCTAssertFalse(jwt.isExpired)
                let token = jwt.token
                // test authenticated request
                var req = URLRequest(url: URL(string: "\(baseUrl)/blockchains")!)
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.setValue("application/json", forHTTPHeaderField: "Accept")
                req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                URLSession.shared.dataTask(with: req) { (data, response, error) in
                    XCTAssertNil(error)
                    XCTAssertEqual((response as? HTTPURLResponse)?.statusCode ?? 0, 200)
                    print("response: \(data != nil ? String(data: data!, encoding: .utf8)! : "none")")
                    exp.fulfill()
                    }.resume()
            case .failure(let error):
                XCTFail("BDB authentication error: \(error)")
                exp.fulfill()
            }
        }

        waitForExpectations(timeout: 30, handler: nil)
    }
}
