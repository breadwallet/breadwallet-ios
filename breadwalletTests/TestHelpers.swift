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
