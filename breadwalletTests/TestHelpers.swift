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
    
    private static let bchMetaData = Data("""
{
  "code": "BCH",
  "name": "Bitcoin Cash",
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
        let associations = Network.Association (baseUnit: BTC_SATOSHI,
                                                defaultUnit: BTC_BTC,
                                                units: Set (arrayLiteral: BTC_SATOSHI, BTC_BTC))
        let fee = NetworkFee (timeInternalInMilliseconds: 30 * 1000,
                              pricePerCostFactor: BRCrypto.Amount.create(integer: 1000, unit: BTC_SATOSHI))
        let network = Network (uids: "bitcoin-mainnet",
                               name: "bitcoin-name",
                               isMainnet: true,
                               currency: btc,
                               height: 100000,
                               associations: [btc:associations],
                               fees: [fee])
        return AppCurrency(core: btc,
                           network: network,
                           metaData: metaData,
                           units: Set([BTC_SATOSHI, BTC_BTC]),
                           baseUnit: BTC_SATOSHI,
                           defaultUnit: BTC_BTC)!
    }
    
    static var bch: AppCurrency {
        let bch = CoreCurrency(uids: "Bitcoin-Cash", name: "Bitcoin Cash", code: "BCH", type: "native", issuer: nil)
        let metaData = try! JSONDecoder().decode(CurrencyMetaData.self, from: bchMetaData)
        let BCH_SATOSHI = BRCrypto.Unit (currency: bch, uids: "BCH-SAT",  name: "Satoshi", symbol: "SAT")
        let BCH_BCH = BRCrypto.Unit (currency: bch, uids: "BCH-BTC",  name: "Bitcoin Cash", symbol: "BCH", base: BCH_SATOSHI, decimals: 8)
        let associations = Network.Association (baseUnit: BCH_SATOSHI,
                                                defaultUnit: BCH_BCH,
                                                units: Set (arrayLiteral: BCH_SATOSHI, BCH_BCH))
        let fee = NetworkFee (timeInternalInMilliseconds: 30 * 1000,
                              pricePerCostFactor: BRCrypto.Amount.create(integer: 1000, unit: BCH_SATOSHI))
        let network = Network (uids: "bitcoin-cash-mainnet",
                               name: "bitcoin-cash-name",
                               isMainnet: true,
                               currency: bch,
                               height: 100000,
                               associations: [bch:associations],
                               fees: [fee])
        return AppCurrency(core: bch,
                           network: network,
                           metaData: metaData,
                           units: Set([BCH_SATOSHI, BCH_BCH]),
                           baseUnit: BCH_SATOSHI,
                           defaultUnit: BCH_BCH)!
    }

    static var eth: AppCurrency {
        let eth = CoreCurrency(uids: "Ethereum", name: "Ethereum", code: "ETH", type: "native", issuer: nil)
        let metaData = try! JSONDecoder().decode(CurrencyMetaData.self, from: ethMetaData)
        let ETH_WEI = BRCrypto.Unit (currency: eth, uids: "ETH-WEI", name: "WEI", symbol: "wei")
        let ETH_GWEI = BRCrypto.Unit (currency: eth, uids: "ETH-GWEI", name: "GWEI",  symbol: "gwei", base: ETH_WEI, decimals: 9)
        let ETH_ETHER = BRCrypto.Unit (currency: eth, uids: "ETH-ETH", name: "ETHER", symbol: "E", base: ETH_WEI, decimals: 18)
        let ETH_associations = Network.Association (baseUnit: ETH_WEI,
                                                    defaultUnit: ETH_ETHER,
                                                    units: Set (arrayLiteral: ETH_WEI, ETH_GWEI, ETH_ETHER))
        let brd = Currency (uids: "BRD", name: "BRD Token", code: "brd", type: "erc20", issuer: "0x558ec3152e2eb2174905cd19aea4e34a23de9ad6")
        
        let brd_brdi = BRCrypto.Unit (currency: brd, uids: "BRD_Integer", name: "BRD Integer", symbol: "BRDI")
        let brd_brd  = BRCrypto.Unit (currency: brd, uids: "BRD_Decimal", name: "BRD_Decimal", symbol: "BRD", base: brd_brdi, decimals: 18)
        
        let BRD_associations = Network.Association (baseUnit: brd_brdi,
                                                    defaultUnit: brd_brd,
                                                    units: Set (arrayLiteral: brd_brdi, brd_brd))
        let fee = NetworkFee (timeInternalInMilliseconds: 1000,
                              pricePerCostFactor: Amount.create(double: 2.0, unit: ETH_GWEI))
        
        let network = Network (uids: "ethereum-mainnet",
                               name: "ethereum-name",
                               isMainnet: true,
                               currency: eth,
                               height: 100000,
                               associations: [eth:ETH_associations, brd:BRD_associations],
                               fees: [fee])
        return AppCurrency(core: eth,
                           network: network,
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
