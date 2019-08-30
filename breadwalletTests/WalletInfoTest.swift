//
//  WalletInfoTest.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-06-29.
//  Copyright © 2017-2019 Breadwinner AG. All rights reserved.
//

import XCTest
import BRCrypto
@testable import breadwallet

class WalletInfoTest : XCTestCase {

    private var client: BRAPIClient?
    private var keyStore: KeyStore!

    override func setUp() {
        super.setUp()
        clearKeychain()
        deleteKvStoreDb()
        keyStore = try! KeyStore.create()
        _ = setupNewAccount(keyStore: keyStore)
        Backend.connect(authenticator: keyStore)
        client = Backend.apiClient
    }

    override func tearDown() {
        super.tearDown()
        Backend.disconnectWallet()
        clearKeychain()
        keyStore.destroy()
    }

    func testRecoverWalletInfo() {
        // 1. Create new wallet info
        guard let kv = client?.kv else { XCTFail("KV store should exist"); return }
        let walletName = "New Wallet"
        let creationDate = Date()
        let connectionModes = [TestCurrencies.btc.uid: WalletManagerMode.p2p_only.serialization,
                               TestCurrencies.eth.uid: WalletManagerMode.api_only.serialization]
        let walletInfo = WalletInfo(name: walletName)
        walletInfo.creationDate = creationDate
        walletInfo.connectionModes = connectionModes
        let _ = try? kv.set(walletInfo)
        let exp = expectation(description: "sync all")

        // 2. Sync new wallet info to server
        kv.syncAllKeys { error in

            // 3. Delete Kv Store and simulate restore wallet
            Backend.disconnectWallet()
            deleteKvStoreDb()
            Backend.connect(authenticator: self.keyStore)
            self.client = Backend.apiClient
            guard let newKv = self.client?.kv else { XCTFail("KV store should exist"); return }

            // 4. Fetch wallet info from remote
            newKv.syncAllKeys { error in
                XCTAssertNil(error, "Sync Error should be nil")
                // 5. Verify fetched wallet info
                if let info = WalletInfo(kvStore: newKv){
                    XCTAssertEqual(info.name, walletName)
                    XCTAssertEqual(info.creationDate.timeIntervalSinceReferenceDate, creationDate.timeIntervalSinceReferenceDate)
                    XCTAssertEqual(info.connectionModes, connectionModes)
                } else {
                    XCTFail("Wallet info should exist")
                }
                exp.fulfill()
            }
        }
        waitForExpectations(timeout: 15.0, handler: nil)
    }

}
