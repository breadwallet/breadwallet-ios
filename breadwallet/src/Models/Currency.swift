//
//  Currency.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2018-01-10.
//  Copyright © 2018 breadwallet LLC. All rights reserved.
//

import Foundation
import BRCore
import BRCrypto
import UIKit

typealias CurrencyUnit = BRCrypto.Unit

/// Combination of the Core Currency model and its metadata properties
class Currency {
    public enum TokenType: String {
        case native
        case erc20
        case unknown
    }

    let core: BRCrypto.Currency

    /// Ticker code (e.g. BTC) -- assumed to be unique
    var code: String { return core.code.uppercased() }
    /// Display name (e.g. Bitcoin)
    var name: String { return core.name }

    var tokenType: TokenType { return TokenType(rawValue: core.type) ?? .unknown }

    /// The smallest divisible unit (e.g. satoshi)
    let baseUnit: CurrencyUnit
    /// The default unit used for fiat exchange rate and amount display (e.g. bitcoin)
    let defaultUnit: CurrencyUnit
    /// All available units for this currency by name
    private let units: [String: CurrencyUnit]

    /// Returns the unit associated with the number of decimals if available
    func unit(forDecimals decimals: Int) -> CurrencyUnit? {
        return units.values.first { $0.decimals == decimals }
    }

    func unit(named name: String) -> CurrencyUnit? {
        return units[name.lowercased()]
    }

    func name(forUnit unit: CurrencyUnit) -> String {
        if unit.decimals == defaultUnit.decimals {
            return code.uppercased()
        } else {
            return unit.name
        }
    }

    func unitName(forDecimals decimals: UInt8) -> String {
        return unitName(forDecimals: Int(decimals))
    }

    func unitName(forDecimals decimals: Int) -> String {
        guard let unit = unit(forDecimals: decimals) else { return "" }
        return name(forUnit: unit)
    }

    // MARK: Metadata

    let metaData: CurrencyMetaData

    /// Primary + secondary color
    var colors: (UIColor, UIColor) { return metaData.colors }
    /// False if a token has been delisted, true otherwise
    var isSupported: Bool { return metaData.isSupported }
    var defaultRate: Double? { return metaData.defaultRate }
    var tokenAddress: String? { return metaData.tokenAddress }

    /// URL scheme for payment requests
    var urlSchemes: [String]? {
        //TODO:CRYPTO url schemes
        if isBitcoin {
            return ["bitcoin"]
        }
        if isBitcoinCash {
            return ["bitcoincash"]
        }
        if isEthereumCompatible {
            return ["ethereum", "ether"]
        }
        return nil
    }

    /// Returns a URI with the given address
    func addressURI(_ address: String) -> String? {
        guard let scheme = urlSchemes?.first, isValidAddress(address) else { return nil }
        return "\(scheme):\(address)"
    }

    // MARK: Init

    init?(core: BRCrypto.Currency,
          metaData: CurrencyMetaData,
          units: Set<BRCrypto.Unit>,
          baseUnit: BRCrypto.Unit,
          defaultUnit: BRCrypto.Unit) {
        guard core.code.caseInsensitiveCompare(metaData.code) == .orderedSame else { return nil }
        self.core = core
        self.metaData = metaData
        self.units = Dictionary(uniqueKeysWithValues: units.lazy.map { ($0.name.lowercased(), $0) })
        self.baseUnit = baseUnit
        self.defaultUnit = defaultUnit
    }
}

extension Currency: Hashable {
    static func == (lhs: Currency, rhs: Currency) -> Bool {
        return lhs.core == rhs.core && lhs.metaData == rhs.metaData
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(core)
        hasher.combine(metaData)
    }
}

// MARK: - Convenience Accessors

extension Currency {
    //TODO:CRYPTO move to wallet(manager)
    func isValidAddress(_ address: String) -> Bool {
        return Store.state[self]?.wallet?.isValidAddress(address) ?? false
    }

    /// Returns true if the currency ticker codes match
    //TODO:CRYPTO replace with ==
    func matches(_ other: Currency) -> Bool {
        return self.code.caseInsensitiveCompare(other.code) == .orderedSame
    }

    /// Ticker code for support pages
    var supportCode: String {
        if tokenType == .erc20 {
            return "erc20"
        } else {
            return code.lowercased()
        }
    }

    //TODO:CRYPTO placeholder
    var isBitcoin: Bool { return code == Currencies.btc.code }
    var isBitcoinCash: Bool { return code == Currencies.bch.code }
    var isEthereum: Bool { return code == Currencies.eth.code }
    var isERC20Token: Bool { return tokenType == .erc20 }
    var isBRDToken: Bool { return code == Currencies.brd.code }
    var isBitcoinCompatible: Bool { return isBitcoin || isBitcoinCash }
    var isEthereumCompatible: Bool { return isEthereum || isERC20Token }
}

// MARK: - Images

extension Currency {
    /// Icon image with square color background
    public var imageSquareBackground: UIImage? {
        if let baseURL = AssetArchive(name: imageBundleName, apiClient: Backend.apiClient)?.extractedUrl {
            let path = baseURL.appendingPathComponent("white-square-bg").appendingPathComponent(code.lowercased()).appendingPathExtension("png")
            if let data = try? Data(contentsOf: path) {
                return UIImage(data: data)
            }
        }
        return TokenImageSquareBackground(currency: self).renderedImage
    }

    /// Icon image with no background using template rendering mode
    public var imageNoBackground: UIImage? {
        if let baseURL = AssetArchive(name: imageBundleName, apiClient: Backend.apiClient)?.extractedUrl {
            let path = baseURL.appendingPathComponent("white-no-bg").appendingPathComponent(code.lowercased()).appendingPathExtension("png")
            if let data = try? Data(contentsOf: path) {
                return UIImage(data: data)?.withRenderingMode(.alwaysTemplate)
            }
        }
        
        return TokenImageNoBackground(currency: self).renderedImage
    }
    
    private var imageBundleName: String {
        return (E.isDebug || E.isTestFlight) ? "brd-tokens-staging" : "brd-tokens"
    }
}

// MARK: - Metadata Model

public struct CurrencyMetaData: Codable {
    let code: String
    let isSupported: Bool
    let colors: (UIColor, UIColor)
    var defaultRate: Double? { return nil } //TODO:CRYPTO
    var tokenAddress: String?

    enum CodingKeys: String, CodingKey {
        case code
        case isSupported = "is_supported"
        case colors
        case tokenAddress = "contract_address"
        //        case name
        //        case type
        //        case decimals = "scale"
        //        case saleAddress = "sale_address"
        //        case defaultRate = "contract_initial_value"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decode(String.self, forKey: .code)
        var colorValues = try container.decode([String].self, forKey: .colors)
        if colorValues.count == 2 {
            colors = (UIColor.fromHex(colorValues[0]), UIColor.fromHex(colorValues[1]))
        } else {
            if E.isDebug {
                throw DecodingError.dataCorruptedError(forKey: .colors, in: container, debugDescription: "Invalid/missing color values")
            }
            colors = (UIColor.black, UIColor.black)
        }
        isSupported = try container.decode(Bool.self, forKey: .isSupported)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(code, forKey: .code)
        var colorValues = [String]()
        colorValues.append(colors.0.toHex)
        colorValues.append(colors.1.toHex)
        try container.encode(colorValues, forKey: .colors)
        try container.encode(isSupported, forKey: .isSupported)
    }
}

extension CurrencyMetaData: Hashable {
    public static func == (lhs: CurrencyMetaData, rhs: CurrencyMetaData) -> Bool {
        return lhs.code == rhs.code
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(code)
    }
}

// MARK: -

//TODO:CRYPTO remove all hard-coded currency references
struct Currencies {
    // swiftlint:disable type_name
    struct btc {
        static var code: String { return "BTC" }
        static var name: String { return "Bitcoin" }
    }

    struct eth {
        static var code: String { return "ETH" }
    }

    struct bch {
        static var code: String { return "BCH" }
        static var name: String { return "Bitcoin Cash" }
    }

    struct brd {
        static var code: String { return "BRD" }
        static var address: String { return "0x558Ec3152e2Eb2174905CD19aeA4e34A23De9ad6" }
    }
}
