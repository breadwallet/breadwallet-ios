//
//  WalletInfoTest.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-06-29.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import XCTest
@testable import loafwallet

private var walletManager: WalletManager?
private var client: BRAPIClient?

//class WalletInfoTest : XCTestCase {
//
//    override class func setUp() {
//        clearKeychain()
//        deleteDb()
//        walletManager = try! WalletManager(store: Store(), dbPath: nil)
//        let _ = walletManager?.setRandomSeedPhrase()
//        client = walletManager?.apiClient
//    }
//
////    func testRecoverWalletInfo() {
////        // 1. Create new wallet info
////        guard let kv = client?.kv else {
////            XCTFail("KV store should exist")
////            return
////        }
////
////        let walletName = "New Wallet"
////        let _ = try? kv.set(WalletInfo(name: walletName))
////        let exp = expectation(description: "sync all")
////
////        // 2. Sync new wallet info to server
////        kv.syncAllKeys { error in
////
////            // 3. Delete Kv Store and simulatore restore wallet
////            client = nil
////            deleteDb()
////            client = BRAPIClient(authenticator: walletManager!)
////            guard let newKv = client?.kv else {
////
////                XCTFail("KV store should exist")
////                return
////            }
////
////            // 4. Fetch wallet info from remote
////            ///Need to be rewritten
//////            newKv.syncAllKeys { error in
//////                print("ERROR: XXX \(error)")
//////                XCTAssertNil(error, "Sync Error should be nil")
//////                // 5. Verify fetched wallet info
//////                if let info = WalletInfo(kvStore: newKv){
//////                    XCTAssert(info.name == walletName, "Wallet name should match")
//////                } else {
//////                    XCTFail("Wallet info should exist")
//////                }
//////                exp.fulfill()
//////            }
////        }
////        waitForExpectations(timeout: 15.0, handler: nil)
////    }
//
//}
