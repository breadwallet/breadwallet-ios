// 
//  Currency.swift
//  breadwallet
//
//  Created by stringcode on 15/02/2021.
//  Copyright © 2021 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import Foundation
import CoinGecko
import UIKit

protocol CurrencyWithIcon {
    var code: String { get }
    var colors: (UIColor, UIColor) { get }
}

typealias CurrencyId = Identifier<Currency>

class Currency: CurrencyWithIcon {

    /// Unique identifier from BlockchainDB
    var uid: CurrencyId { return metaData.uid }
    /// Display name (e.g. Bitcoin)
    var name: String { return metaData.name }

    var coinGeckoId: String? {
        return metaData.coinGeckoId
    }
    
    var code: String {
        return metaData.code.uppercased()
    }

    // MARK: Metadata

    let metaData: CurrencyMetaData

    /// Primary + secondary color
    var colors: (UIColor, UIColor) { return metaData.colors }
    /// False if a token has been delisted, true otherwise
    var isSupported: Bool { return metaData.isSupported }

    // MARK: URI

    var urlSchemes: [String]? {
        if isBitcoin {
            return ["bitcoin"]
        }
        if isBitcoinCash {
            return E.isTestnet ? ["bchtest"] : ["bitcoincash"]
        }
        if isEthereumCompatible {
            return ["ethereum"]
        }
        if isXRP {
            return ["xrpl", "xrp", "ripple"]
        }
        if isHBAR {
            return ["hbar"]
        }
        return nil
    }
    
    init(metaData: CurrencyMetaData) {
        self.metaData = metaData
    }
}

// MARK: - Convenience Accessors

extension Currency {

    var isBitcoin: Bool { return uid == Currencies.btc.uid }
    var isBitcoinCash: Bool { return uid == Currencies.bch.uid }
    var isEthereum: Bool { return uid == Currencies.eth.uid }
    var isERC20Token: Bool { return metaData.type == "ERC20" }
    var isBRDToken: Bool { return uid == Currencies.brd.uid }
    var isXRP: Bool { return uid == Currencies.xrp.uid }
    var isHBAR: Bool { return uid == Currencies.hbar.uid }
    var isEthereumCompatible: Bool { return isEthereum || isERC20Token }
}

/// Model representing metadata for supported currencies
public struct CurrencyMetaData: CurrencyWithIcon {
    
    let uid: CurrencyId
    let code: String
    let isSupported: Bool
    let colors: (UIColor, UIColor)
    let name: String
    var tokenAddress: String?
    var decimals: UInt8
    
    var isPreferred: Bool {
        return Currencies.allCases.map { $0.uid }.contains(uid)
    }

    /// token type string in format expected by System.asBlockChainDBModelCurrency
    var type: String {
        return uid.rawValue.contains("__native__") ? "NATIVE" : "ERC20"
    }

    var alternateCode: String?
    var coinGeckoId: String?
    
    enum CodingKeys: String, CodingKey {
        case uid = "currency_id"
        case code
        case isSupported = "is_supported"
        case colors
        case tokenAddress = "contract_address"
        case name
        case decimals = "scale"
        case alternateNames = "alternate_names"
    }
}

extension CurrencyMetaData: Decodable {
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        //TODO:CRYPTO temp hack until testnet support to added /currencies endpoint (BAK-318)
        var uid = try container.decode(String.self, forKey: .uid)
        if E.isTestnet {
            uid = uid.replacingOccurrences(of: "mainnet", with: "testnet")
            uid = uid.replacingOccurrences(of: "0x558ec3152e2eb2174905cd19aea4e34a23de9ad6", with: "0x7108ca7c4718efa810457f228305c9c71390931a") // BRD token
            uid = uid.replacingOccurrences(of: "ethereum-testnet", with: "ethereum-ropsten")
        }
        self.uid = CurrencyId(rawValue: uid) //try container.decode(CurrencyId.self, forKey: .uid)
        code = try container.decode(String.self, forKey: .code)
        let colorValues = try container.decode([String].self, forKey: .colors)
        if colorValues.count == 2 {
            colors = (UIColor.fromHex(colorValues[0]), UIColor.fromHex(colorValues[1]))
        } else {
            if E.isDebug {
                throw DecodingError.dataCorruptedError(forKey: .colors, in: container, debugDescription: "Invalid/missing color values")
            }
            colors = (UIColor.black, UIColor.black)
        }
        isSupported = try container.decode(Bool.self, forKey: .isSupported)
        name = try container.decode(String.self, forKey: .name)
        tokenAddress = try container.decode(String.self, forKey: .tokenAddress)
        decimals = try container.decode(UInt8.self, forKey: .decimals)
        
        var didFindCoinGeckoID = false
        if let alternateNames = try? container.decode([String: String].self, forKey: .alternateNames) {
            if let code = alternateNames["cryptocompare"] {
                alternateCode = code
            }
            
            if let id = alternateNames["coingecko"] {
                didFindCoinGeckoID = true
                coinGeckoId = id
            }
        }
        
        // If the /currencies endpoint hasn't provided a coingeckoID,
        // use the local list. Eventually /currencies should provide
        // all of them
        if !didFindCoinGeckoID {
            if let id = CoinGeckoCodes.map[code.uppercased()] {
                coinGeckoId = id
            }
        }
    }
}

extension CurrencyMetaData: Hashable {
    public static func == (lhs: CurrencyMetaData, rhs: CurrencyMetaData) -> Bool {
        return lhs.uid == rhs.uid
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(uid)
    }
}

/// Natively supported currencies. Enum maps to ticker code.
enum Currencies: String, CaseIterable {
    case btc
    case bch
    case eth
    case brd
    case tusd
    case xrp
    case hbar
    case xtz
    
    var code: String { return rawValue }
    var uid: CurrencyId {
        var uids = ""
        switch self {
        case .btc:
            uids = "bitcoin-\(E.isTestnet ? "testnet" : "mainnet"):__native__"
        case .bch:
            uids = "bitcoincash-\(E.isTestnet ? "testnet" : "mainnet"):__native__"
        case .eth:
            uids = "ethereum-\(E.isTestnet ? "ropsten" : "mainnet"):__native__"
        case .brd:
            uids = "ethereum-mainnet:0x558ec3152e2eb2174905cd19aea4e34a23de9ad6"
        case .tusd:
            uids = "ethereum-mainnet:0x0000000000085d4780B73119b644AE5ecd22b376"
        case .xrp:
            uids = "ripple-\(E.isTestnet ? "testnet" : "mainnet"):__native__"
        case .hbar:
            uids = "hedera-mainnet:__native__"
        case .xtz:
            uids = "tezos-mainnet:__native__"
        }
        return CurrencyId(rawValue: uids)
    }
}

// MARK: - AssetOption

extension Currency {

    func assetOption() -> AssetOption {
        return AssetOption(identifier: uid.rawValue, display: name)
    }
}
