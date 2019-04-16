//
//  TestHelpers.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-02-26.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation
import XCTest
@testable import breadwallet
@testable import BRCrypto

struct Currencies {
    private let btcMetaData = Data("""
{
  "code": "BTC",
  "name": "Bitcoin",
  "type": "",
  "scale": 8,
  "is_supported": true,
  "contract_address": "",
  "sale_address": "",
  "aliases": [],
  "colors": [
    "#f29500",
    "#f29500"
  ]
}
""".utf8)

    var btc: Currency? {
        let btc = BRCrypto.Currency(uids: "Bitcoin", name: "Bitcoin", code: "BTC", type: "native")
        let metaData = try! JSONDecoder().decode(CurrencyMetaData.self, from: btcMetaData)
        let BTC_SATOSHI = BRCrypto.Unit (currency: btc, uids: "BTC-SAT",  name: "Satoshi", symbol: "SAT")
        let BTC_BTC = BRCrypto.Unit (currency: btc, uids: "BTC-BTC",  name: "Bitcoin", symbol: "B", base: BTC_SATOSHI, decimals: 8)
        return CurrencyViewModel(model: btc,
                                 metaData: metaData,
                                 units: Set([BTC_SATOSHI, BTC_BTC]),
                                 baseUnit: BTC_SATOSHI,
                                 defaultUnit: BTC_BTC)
    }
}

func clearKeychain() {
    let classes = [kSecClassGenericPassword as String,
                   kSecClassInternetPassword as String,
                   kSecClassCertificate as String,
                   kSecClassKey as String,
                   kSecClassIdentity as String]
    classes.forEach { className in
        SecItemDelete([kSecClass as String: className]  as CFDictionary)
    }
}

func deleteKvStoreDb() {
    let fm = FileManager.default
    let docsUrl = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
    let url = docsUrl.appendingPathComponent("kvstore.sqlite3")
    if fm.fileExists(atPath: url.path) {
        do {
            try fm.removeItem(at: url)
        } catch let error {
            XCTFail("Could not delete kv store data: \(error)")
        }
    }
}

func initWallet(walletManager: BTCWalletManager) {
    guard walletManager.wallet == nil else { return }
    if walletManager.db == nil {
        walletManager.db = CoreDatabase()
    }
    var didInitWallet = false
    walletManager.initWallet { success in
        didInitWallet = success
    }
    while !didInitWallet {
        //This Can't use a semaphore because the initWallet callback gets called on the main thread
        RunLoop.current.run(mode: RunLoop.Mode.default, before: .distantFuture)
    }
}

func setupNewWallet(keyStore: KeyStore) -> BTCWalletManager? {
    let _ = keyStore.setRandomSeedPhrase()
    guard let mpk = keyStore.masterPubKey else { XCTFail("masterPubKey should not be nil"); return nil }

    guard let walletManager = try? BTCWalletManager(currency: Currencies.btc,
                                                       masterPubKey: mpk,
                                                       earliestKeyTime: keyStore.creationTime,
                                                       dbPath: Currencies.btc.dbPath) else {
                                                        XCTFail("failed to create BTCWalletManager")
                                                        return nil
    }
    initWallet(walletManager: walletManager)
    return walletManager
}
