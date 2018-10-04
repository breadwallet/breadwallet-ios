//
//  Currency.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2018-01-10.
//  Copyright © 2018 breadwallet LLC. All rights reserved.
//

import Foundation
import BRCore
import UIKit

// MARK: - Protocols

/// Represents common properties of cryptocurrency types
public protocol CurrencyDef {
    /// Ticker code -- assumed to be unique
    var code: String { get }
    /// Primary unit symbol
    var symbol: String { get }
    var name: String { get }
    /// The common unit used for fiat exchange rate and amount display
    var commonUnit: CurrencyUnit { get }
    /// Primary + secondary color
    var colors: (UIColor, UIColor) { get }
    /// URL scheme for payment requests
    var urlSchemes: [String]? { get }
    /// Returns true if the currency ticker codes match
    func matches(_ other: CurrencyDef) -> Bool
    /// Checks address validity in currency-specific format
    func isValidAddress(_ address: String) -> Bool
    /// Returns a URI with the given address
    func addressURI(_ address: String) -> String?
    
    /// Icon image with square color background
    var imageSquareBackground: UIImage? { get }
    /// Icon image with no background using template rendering mode
    var imageNoBackground: UIImage? { get }
    
    /// Returns the unit associated with the number of decimals
    func unit(forDecimals decimals: Int) -> CurrencyUnit?
    /// Returns the abbreviated name for given unit
    func name(forUnit unit: CurrencyUnit) -> String
    /// Returns the abbreviated unit name for given decimals
    func unitName(forDecimals decimals: Int) -> String
    /// Returns the symbol for given unit or its name if no symbol defined
    func symbol(forUnit unit: CurrencyUnit) -> String
}

public extension CurrencyDef {
    var urlSchemes: [String]? {
        return nil
    }
    
    func matches(_ other: CurrencyDef) -> Bool {
        return self.code == other.code
    }
    
    func addressURI(_ address: String) -> String? {
        guard let schemes = urlSchemes, schemes.count > 0, isValidAddress(address) else { return nil }
        return "\(schemes[0]):\(address)"
    }
    
    func unit(forDecimals decimals: Int) -> CurrencyUnit? {
        return TokenUnit(decimals: decimals, name: code)
    }
    
    func name(forUnit unit: CurrencyUnit) -> String {
        if unit.decimals == commonUnit.decimals {
            return code.uppercased()
        } else {
            return unit.name
        }
    }

    func symbol(forUnit unit: CurrencyUnit) -> String {
        if unit.decimals == commonUnit.decimals {
            return symbol
        } else {
            return name(forUnit: unit)
        }
    }
    
    func unitName(forDecimals decimals: Int) -> String {
        guard let unit = unit(forDecimals: decimals) else { return "" }
        return name(forUnit: unit)
    }
    
    var supportCurrencyCode: String {
        if self is ERC20Token {
            return "erc20"
        } else {
            return code.lowercased()
        }
    }
}

// MARK: - Images

extension CurrencyDef {
    public var imageSquareBackground: UIImage? {
        if let baseURL = AssetArchive(name: imageBundleName, apiClient: Backend.apiClient)?.extractedUrl {
            let path = baseURL.appendingPathComponent("white-square-bg").appendingPathComponent(code.lowercased()).appendingPathExtension("png")
            if let data = try? Data(contentsOf: path) {
                return UIImage(data: data)
            }
        }
        return TokenImageSquareBackground(currency: self).renderedImage
    }
    
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

// MARK: - Units

/// Represents the unit of account for a token
public protocol CurrencyUnit {
    /// Base unit (e.g. Satoshis) multiplier, as a power of 10
    var decimals: Int { get }
    var name: String { get }
}

public extension CurrencyUnit where Self: RawRepresentable, Self.RawValue == Int {
    var decimals: Int { return rawValue }
    var name: String { return String(describing: self) }
}

/// A generic token unit with variable decimals
public struct TokenUnit: CurrencyUnit {
    public var decimals: Int
    public var name: String
}

/// MARK: - Currency Definitions

/// Bitcoin-compatible currency type
public struct Bitcoin: CurrencyDef {
    
    public enum Units: Int, CurrencyUnit {
        case satoshi = 0
        case bit = 2
        case millibitcoin = 5
        case bitcoin = 8 // 1 Satoshi = 1e-8 BTC
    }
    
    public let name: String
    public let code: String
    public let symbol: String
    public let colors: (UIColor, UIColor)
    let dbPath: String
    let forkId: Int
    public let urlSchemes: [String]?
    
    public var commonUnit: CurrencyUnit {
        return Units.bitcoin
    }
    
    public func isValidAddress(_ address: String) -> Bool {
        if self.matches(Currencies.bch) {
            return address.isValidBCHAddress
        } else {
            return address.isValidAddress
        }
    }
    
    public func addressURI(_ address: String) -> String? {
        guard let schemes = urlSchemes, isValidAddress(address) else { return nil }
        if self.matches(Currencies.bch) {
            return address
        } else {
            return "\(schemes[0]):\(address)"
        }
    }
    
    public func unit(forDecimals decimals: Int) -> CurrencyUnit? {
        return Units(rawValue: decimals)
    }
    
    public func name(forUnit unit: CurrencyUnit) -> String {
        guard let unit = unit as? Units else { return "" }
        switch unit {
        case .satoshi:
            return "sat"
        case .bit:
            return (self.code == Currencies.btc.code) ? "bits" : "μ\(code.uppercased())"
        case .millibitcoin:
            return "m\(code.uppercased())"
        case .bitcoin:
            return code.uppercased()
        }
    }
    
    public func symbol(forUnit unit: CurrencyUnit) -> String {
        guard let unit = unit as? Units else { return "" }
        switch unit {
        case .bit:
            return S.Symbols.bits
        case .millibitcoin:
            return "m\(symbol)"
        case .bitcoin:
            return symbol
        default:
            return name(forUnit: unit)
        }
    }
}

/// Ethereum-compatible currency type
public struct Ethereum: CurrencyDef {
    
    enum Units: Int, CurrencyUnit {
        case wei = 0
        case kwei = 3
        case mwei = 6
        case gwei = 9
        case micro = 12
        case milli = 15
        case eth = 18 // 1 Wei = 1e-18 ETH
    }
    
    public let name: String
    public let code: String
    public let symbol: String
    public let colors: (UIColor, UIColor)
    public let urlSchemes: [String]?
    
    public var commonUnit: CurrencyUnit {
        return Units.eth
    }
    
    public func isValidAddress(_ address: String) -> Bool {
        return address.isValidEthAddress
    }
    
    public func unit(forDecimals decimals: Int) -> CurrencyUnit? {
        return Units(rawValue: decimals)
    }
}

/// Ethereum ERC20 token currency type
public struct ERC20Token: CurrencyDef {
    public let name: String
    public let code: String
    public let symbol: String
    public let colors: (UIColor, UIColor)
    
    /// token contract address
    public let address: String
    public let abi: String
    public let decimals: Int
    
    public let isSupported: Bool
    public let saleAddress: String?
    public let defaultRate: Double?
    
    public var commonUnit: CurrencyUnit {
        return TokenUnit(decimals: decimals, name: code)
    }
    
    public func isValidAddress(_ address: String) -> Bool {
        return address.isValidEthAddress
    }
    
    public var urlSchemes: [String]? {
        return Currencies.eth.urlSchemes
    }
}

extension ERC20Token: Codable {
    enum CodingKeys: String, CodingKey {
        case code
        case address = "contract_address"
        case name
        case decimals = "scale"
        case isSupported = "is_supported"
        case saleAddress = "sale_address"
        case defaultRate = "contract_initial_value"
        case colors
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // on testnet all tokens get the BRD testnet address
        address = E.isTestnet ? Currencies.brd.address : try container.decode(String.self, forKey: .address)
        name = try container.decode(String.self, forKey: .name)
        code = try container.decode(String.self, forKey: .code)
        symbol = code
        abi = ERC20Token.standardAbi
        decimals = try container.decode(Int.self, forKey: .decimals)
        var colorValues = try container.decode([String].self, forKey: .colors)
        guard colorValues.count == 2 else {
            throw DecodingError.dataCorruptedError(forKey: .colors, in: container, debugDescription: "Invalid color values")
        }
        colors = (UIColor.fromHex(colorValues[0]), UIColor.fromHex(colorValues[1]))
        isSupported = try container.decode(Bool.self, forKey: .isSupported)
        saleAddress = (try? container.decode(String.self, forKey: .saleAddress)) ?? nil
        // contains currency code prefix e.g. "ETH 0.00125000"
        if let rateText = (try? container.decode(String.self, forKey: .defaultRate)) {
            defaultRate = Double(String(rateText.trimmingCharacters(in: CharacterSet(charactersIn: "01234567890.").inverted)))
        } else {
            defaultRate = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(address, forKey: .address)
        try container.encode(name, forKey: .name)
        try container.encode(code, forKey: .code)
        try container.encode(decimals, forKey: .decimals)
        var colorValues = [String]()
        colorValues.append(colors.0.toHex)
        colorValues.append(colors.1.toHex)
        try container.encode(colorValues, forKey: .colors)
        try container.encode(isSupported, forKey: .isSupported)
        try container.encode(saleAddress, forKey: .saleAddress)
        try container.encode(defaultRate, forKey: .defaultRate)
    }
}

// MARK: Instances

public struct Currencies {
    static let btc = Bitcoin(name: "Bitcoin",
                             code: "BTC",
                             symbol: S.Symbols.btc,
                             colors: (UIColor(red:0.972549, green:0.623529, blue:0.200000, alpha:1.0), UIColor(red:0.898039, green:0.505882, blue:0.031373, alpha:1.0)),
                             dbPath: "BreadWallet.sqlite",
                             forkId: 0,
                             urlSchemes: ["bitcoin"])
    
    static let bch = Bitcoin(name: "Bitcoin Cash",
                             code: "BCH",
                             symbol: S.Symbols.btc,
                             colors: (UIColor(red:0.278431, green:0.521569, blue:0.349020, alpha:1.0), UIColor(red:0.278431, green:0.521569, blue:0.349020, alpha:1.0)),
                             dbPath: "BreadWallet-bch.sqlite",
                             forkId: 0x40,
                             urlSchemes: E.isTestnet ? ["bchtest", "bitcoincash"] :  ["bitcoincash"])
    
    static let eth = Ethereum(name: "Ethereum",
                              code: "ETH",
                              symbol: S.Symbols.eth,
                              colors: (UIColor(red:0.37, green:0.44, blue:0.64, alpha:1.0), UIColor(red:0.37, green:0.44, blue:0.64, alpha:1.0)),
                              urlSchemes: ["ethereum", "ether"])
    
    static let brd = ERC20Token(name: "BRD",
                                code: "BRD",
                                symbol: "🍞",
                                colors: (UIColor.fromHex("ff5193"), UIColor.fromHex("f9a43a")),
                                address: E.isTestnet ? "0x7108ca7c4718efa810457f228305c9c71390931a" : "0x558ec3152e2eb2174905cd19aea4e34a23de9ad6",
                                abi: ERC20Token.standardAbi,
                                decimals: 18,
                                isSupported: true,
                                saleAddress: nil,
                                defaultRate: nil)
    
    static let tst = ERC20Token(name: "Test Token",
                                code: "TST",
                                symbol: "TST",
                                colors: (UIColor.fromHex("2FB8E6"), UIColor.fromHex("2FB8E6")),
                                address: E.isTestnet ?  "0x722dd3f80bac40c951b51bdd28dd19d435762180" : "0x3efd578b271d034a69499e4a2d933c631d44b9ad",
                                abi: ERC20Token.standardAbi,
                                decimals: 18,
                                isSupported: true,
                                saleAddress: nil,
                                defaultRate: nil)
}
