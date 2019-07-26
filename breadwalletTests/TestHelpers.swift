//
//  TestHelpers.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-02-26.
//  Copyright © 2017-2019 Breadwinner AG. All rights reserved.
//

import Foundation
import XCTest
@testable import breadwallet
@testable import BRCrypto

let testWalletSecAttrService = "com.brd.testnetQA.tests"

typealias CoreCurrency = BRCrypto.Currency
typealias AppCurrency = breadwallet.Currency

struct Currencies {
    private static let btcMetaData = Data("""
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

    private static let ethMetaData = Data("""
{
  "code": "ETH",
  "name": "Ethereum",
  "type": "",
  "scale": 18,
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

    static var btc: AppCurrency {
        let btc = CoreCurrency(uids: "Bitcoin", name: "Bitcoin", code: "BTC", type: "native", issuer: nil)
        let metaData = try! JSONDecoder().decode(CurrencyMetaData.self, from: btcMetaData)
        let BTC_SATOSHI = BRCrypto.Unit (currency: btc, uids: "BTC-SAT",  name: "Satoshi", symbol: "SAT")
        let BTC_BTC = BRCrypto.Unit (currency: btc, uids: "BTC-BTC",  name: "Bitcoin", symbol: "B", base: BTC_SATOSHI, decimals: 8)
        return AppCurrency(core: btc,
                           metaData: metaData,
                           units: Set([BTC_SATOSHI, BTC_BTC]),
                           baseUnit: BTC_SATOSHI,
                           defaultUnit: BTC_BTC)!
    }

    static var eth: AppCurrency {
        let eth = CoreCurrency(uids: "Ethereum", name: "Ethereum", code: "ETH", type: "native", issuer: nil)
        let metaData = try! JSONDecoder().decode(CurrencyMetaData.self, from: ethMetaData)
        let ETH_WEI = BRCrypto.Unit (currency: eth, uids: "ETH-WEI", name: "WEI", symbol: "wei")
        let ETH_GWEI = BRCrypto.Unit (currency: eth, uids: "ETH-GWEI", name: "GWEI",  symbol: "gwei", base: ETH_WEI, decimals: 9)
        let ETH_ETHER = BRCrypto.Unit (currency: eth, uids: "ETH-ETH", name: "ETHER", symbol: "E", base: ETH_WEI, decimals: 18)
        return AppCurrency(core: eth,
                           metaData: metaData,
                           units: Set([ETH_WEI, ETH_GWEI, ETH_ETHER]),
                           baseUnit: ETH_WEI,
                           defaultUnit: ETH_ETHER)!
    }
}

func clearKeychain() {
    let classes = [kSecClassGenericPassword as String,
                   kSecClassInternetPassword as String,
                   kSecClassCertificate as String,
                   kSecClassKey as String,
                   kSecClassIdentity as String]
    classes.forEach { className in
        SecItemDelete([kSecClass as String: className,
                       kSecAttrService: testWalletSecAttrService] as CFDictionary)
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

func setupNewAccount(keyStore: KeyStore, pin: String = "111111") -> Account? {
    guard keyStore.setPin(pin) else { return nil }
    guard let (_, account) = keyStore.setRandomSeedPhrase() else { return nil }
    return account
}
