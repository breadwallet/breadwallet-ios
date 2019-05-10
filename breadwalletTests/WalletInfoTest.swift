//
//  WalletInfoTest.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-06-29.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import XCTest
@testable import breadwallet
@testable import BRCrypto

class WalletInfoTest : XCTestCase {

    private var client: BRAPIClient?
    private var keyStore: KeyStore!

    override func setUp() {
        super.setUp()
        clearKeychain()
        deleteKvStoreDb()
        keyStore = try! KeyStore.create()
        _ = setupNewAccount(keyStore: keyStore)
        client = BRAPIClient(authenticator: keyStore)
    }

    override func tearDown() {
        super.tearDown()
        clearKeychain()
        keyStore.destroy()
    }

    func testRecoverWalletInfo() {
        // 1. Create new wallet info
        guard let kv = client?.kv else { XCTFail("KV store should exist"); return }
        let walletName = "New Wallet"
        let _ = try? kv.set(WalletInfo(name: walletName))
        let exp = expectation(description: "sync all")

        // 2. Sync new wallet info to server
        kv.syncAllKeys { error in

            // 3. Delete Kv Store and simulate restore wallet
            self.client = nil
            deleteKvStoreDb()
            self.client = BRAPIClient(authenticator: self.keyStore)
            guard let newKv = self.client?.kv else { XCTFail("KV store should exist"); return }

            // 4. Fetch wallet info from remote
            newKv.syncAllKeys { error in
                XCTAssertNil(error, "Sync Error should be nil")
                // 5. Verify fetched wallet info
                if let info = WalletInfo(kvStore: newKv){
                    XCTAssert(info.name == walletName, "Wallet name should match")
                } else {
                    XCTFail("Wallet info should exist")
                }
                exp.fulfill()
            }
        }
        waitForExpectations(timeout: 15.0, handler: nil)
    }

}
