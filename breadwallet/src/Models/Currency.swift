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
    var urlScheme: String? { get }
    /// Returns true if the currency ticker codes match
    func matches(_ other: CurrencyDef) -> Bool
    /// Checks address validity in currency-specific format
    func isValidAddress(_ address: String) -> Bool
    /// Returns a URI with the given address
    func addressURI(_ address: String) -> String?
    
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
    var urlScheme: String? {
        return nil
    }
    
    func matches(_ other: CurrencyDef) -> Bool {
        return self.code == other.code
    }
    
    func addressURI(_ address: String) -> String? {
        guard let scheme = urlScheme, isValidAddress(address) else { return nil }
        return "\(scheme):\(address)"
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
    public let urlScheme: String?
    
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
        guard let scheme = urlScheme, isValidAddress(address) else { return nil }
        if self.matches(Currencies.bch) {
            return address
        } else {
            return "\(scheme):\(address)"
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
    public let urlScheme: String?
    
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
    
    public let address: String
    public let abi: String
    public let decimals: Int
    
    public var commonUnit: CurrencyUnit {
        return TokenUnit(decimals: decimals, name: code)
    }
    
    public func isValidAddress(_ address: String) -> Bool {
        return address.isValidEthAddress
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
                             urlScheme: "bitcoin")
    static let bch = Bitcoin(name: "Bitcoin Cash",
                             code: "BCH",
                             symbol: S.Symbols.btc,
                             colors: (UIColor(red:0.278431, green:0.521569, blue:0.349020, alpha:1.0), UIColor(red:0.278431, green:0.521569, blue:0.349020, alpha:1.0)),
                             dbPath: "BreadWallet-bch.sqlite",
                             forkId: 0x40,
                             urlScheme: E.isTestnet ? "bchtest" : "bitcoincash")
    static let eth = Ethereum(name: "Ethereum",
                              code: "ETH",
                              symbol: S.Symbols.eth,
                              colors: (UIColor(red:0.37, green:0.44, blue:0.64, alpha:1.0), UIColor(red:0.37, green:0.44, blue:0.64, alpha:1.0)),
                              urlScheme: "ethereum")
    static let brd = ERC20Token(name: "BRD",
                                code: "BRD",
                                symbol: "🍞",
                                colors: (UIColor(red:0.95, green:0.65, blue:0.00, alpha:1.0), UIColor(red:0.95, green:0.35, blue:0.13, alpha:1.0)),
                                address: E.isTestnet ? "0x7108ca7c4718efa810457f228305c9c71390931a" :  "0x558ec3152e2eb2174905cd19aea4e34a23de9ad6",
                                abi: ERC20Token.standardAbi,
                                decimals: 18)
    
    static let tst = ERC20Token(name: "Test Token",
                                code: "TST",
                                symbol: "",
                                colors: (UIColor(red:0.37, green:0.44, blue:0.64, alpha:1.0), UIColor.darkPurple),
                                address: E.isTestnet ?  "0x722dd3f80bac40c951b51bdd28dd19d435762180" : "0x3efd578b271d034a69499e4a2d933c631d44b9ad",
                                abi: ERC20Token.standardAbi,
                                decimals: 18)
    
}
