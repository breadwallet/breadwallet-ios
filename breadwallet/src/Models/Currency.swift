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
protocol CurrencyDef {
    /// Ticker code -- assumed to be unique
    var code: String { get }
    /// Primary unit symbol
    var symbol: String { get }
    var name: String { get }
    /// Base unit to primary unit multiplier
    var baseUnit: Double { get }
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
    /// Returns the unit name for given denomination or empty string
    func unitName(maxDigits: Int) -> String
    /// Returns the unit symbol for given denomination or empty string
    func unitSymbol(maxDigits: Int) -> String
}

extension CurrencyDef {
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
    
    func unitName(maxDigits: Int) -> String {
        return ""
    }
    
    func unitSymbol(maxDigits: Int) -> String {
        return ""
    }
}

/// MARK: - Currency Definitions

/// Bitcoin-compatible currency type
struct Bitcoin: CurrencyDef {
    let baseUnit = 100000000.0
    let name: String
    let code: String
    let symbol: String
    let colors: (UIColor, UIColor)
    let dbPath: String
    let forkId: Int
    let urlScheme: String?
    
    func isValidAddress(_ address: String) -> Bool {
        if self.matches(Currencies.bch) {
            return address.isValidBCHAddress
        } else {
            return address.isValidAddress
        }
    }
    
    func addressURI(_ address: String) -> String? {
        guard let scheme = urlScheme, isValidAddress(address) else { return nil }
        if self.matches(Currencies.bch) {
            return address
        } else {
            return "\(scheme):\(address)"
        }
    }
    
    func unitName(maxDigits: Int) -> String {
        switch maxDigits {
        case 2:
            return "Bits"
        case 8:
            return code.uppercased()
        default:
            return ""
        }
    }
    
    func unitSymbol(maxDigits: Int) -> String {
        switch maxDigits {
        case 2:
            return S.Symbols.bits
        case 5:
            return "m\(S.Symbols.btc)"
        case 8:
            return S.Symbols.btc
        default:
            return S.Symbols.bits
        }
    }
}

/// Ethereum-compatible currency type
struct Ethereum: CurrencyDef {
    let baseUnit: Double = 1000000000000000000.0
    let name: String
    let code: String
    let symbol: String
    let colors: (UIColor, UIColor)
    
    func isValidAddress(_ address: String) -> Bool {
        return address.isValidEthAddress
    }
}

/// Ethereum ERC20 token currency type
struct ERC20Token: CurrencyDef {
    let baseUnit: Double = 1000000000000000000.0
    let name: String
    let code: String
    let symbol: String
    let address: String
    let decimals: Int
    let abi: String
    let colors: (UIColor, UIColor)
    
    func isValidAddress(_ address: String) -> Bool {
        return address.isValidEthAddress
    }
}

// MARK: Instances

struct Currencies {
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
                              colors: (UIColor(red:0.407843, green:0.529412, blue:0.654902, alpha:1.0), UIColor(red:0.180392, green:0.278431, blue:0.376471, alpha:1.0)))
    static let brd = ERC20Token(name: "Bread Token",
                                code: "BRD",
                                symbol: "🍞",
                                address: "0x558ec3152e2eb2174905cd19aea4e34a23de9ad6",
                                decimals: 18,
                                abi: "", //TODO:BRD - add erc20 abi
                                colors: (UIColor(red:0.95, green:0.65, blue:0.00, alpha:1.0), UIColor(red:0.95, green:0.35, blue:0.13, alpha:1.0)))
}
