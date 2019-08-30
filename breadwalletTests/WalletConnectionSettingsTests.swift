// 
//  WalletConnectionSettingsTests.swift
//  breadwalletTests
//
//  Created by Ehsan Rezaie on 2019-08-29.
//  Copyright © 2019 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import XCTest
import BRCrypto
@testable import breadwallet

class WalletConnectionSettingsTests: XCTestCase {

    private var client: BRAPIClient?
    private var keyStore: KeyStore!
    private var system: CoreSystem!

    override func setUp() {
        super.setUp()
        clearKeychain()
        deleteKvStoreDb()
        keyStore = try! KeyStore.create()
        let account = setupNewAccount(keyStore: keyStore)
        Backend.connect(authenticator: keyStore)
        client = Backend.apiClient
        system = CoreSystem()
        system.create(account: account!, authToken: "")
    }

    override func tearDown() {
        super.tearDown()
        system.shutdown(completion: nil)
        Backend.disconnectWallet()
        clearKeychain()
        keyStore.destroy()
    }

    func testDefaultConnectionModes() {
        guard let kv = client?.kv else { XCTFail("KV store should exist"); return }
        let walletInfo = WalletInfo(name: "Test") // empty WalletInfo with no saved modes
        let settings = WalletConnectionSettings(system: system, kvStore: kv, walletInfo: walletInfo)
        let expectedDefaultModes: [AppCurrency: WalletManagerMode] = [Currencies.btc: .p2p_only,
                                                                      Currencies.bch: .p2p_only,
                                                                      Currencies.eth: .api_only]

        expectedDefaultModes.forEach { (currency, expectedMode) in
            XCTAssertEqual(WalletConnectionSettings.defaultMode(for: currency), expectedMode)
            XCTAssertEqual(settings.mode(for: currency), expectedMode)
        }
    }

    func testRetrievingModes() {
        guard let kv = client?.kv else { XCTFail("KV store should exist"); return }
        let walletInfo = WalletInfo(name: "Test")
        // init with non-default modes
        let connectionModes = [Currencies.btc.uid: WalletManagerMode.api_only,
                               Currencies.eth.uid: WalletManagerMode.api_with_p2p_submit]
        walletInfo.connectionModes = connectionModes.mapValues { $0.serialization }
        let settings = WalletConnectionSettings(system: system, kvStore: kv, walletInfo: walletInfo)

        // verify stored modes are returned
        XCTAssertEqual(settings.mode(for: Currencies.btc), connectionModes[Currencies.btc.uid])
        XCTAssertEqual(settings.mode(for: Currencies.eth), connectionModes[Currencies.eth.uid])

        // verify default is returned for currency with no set mode
        XCTAssertEqual(settings.mode(for: Currencies.bch), WalletConnectionSettings.defaultMode(for: Currencies.bch))
    }

    func testChangingModes() {
        guard let kv = client?.kv else { XCTFail("KV store should exist"); return }
        let walletInfo = WalletInfo(name: "Test")
        // init with non-default modes
        let connectionModes = [Currencies.btc.uid: WalletManagerMode.p2p_only,
                               Currencies.eth.uid: WalletManagerMode.api_only]
        walletInfo.connectionModes = connectionModes.mapValues { $0.serialization }
        let settings = WalletConnectionSettings(system: system, kvStore: kv, walletInfo: walletInfo)

        settings.set(mode: .api_only, for: Currencies.btc)
        settings.set(mode: .api_with_p2p_submit, for: Currencies.eth)

        XCTAssertEqual(settings.mode(for: Currencies.btc), WalletManagerMode.api_only)
        XCTAssertEqual(settings.mode(for: Currencies.eth), WalletManagerMode.api_with_p2p_submit)
    }

}
