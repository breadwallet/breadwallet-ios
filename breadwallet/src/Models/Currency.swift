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
    var code: String { get }
    var symbol: String { get }
    var name: String { get }
    var baseUnit: Double { get }
    var colors: (UIColor, UIColor) { get }
    var state: CurrencyState { get }
    func mutate(state: CurrencyState) -> CurrencyDef
}

struct CurrencyState {
    let rate: Rate?
    let fees: Fees?
    let balance: UInt64?

    static var initial: CurrencyState {
        return CurrencyState(rate: nil, fees: nil, balance: nil)
    }
}

// MARK: - Currency Definitions

/// Bitcoin-compatible currency type
struct Bitcoin: CurrencyDef {
    let baseUnit = 100000000.0
    let name: String
    let code: String
    let symbol: String
    let colors: (UIColor, UIColor)
    let state: CurrencyState

    func mutate(state: CurrencyState) -> CurrencyDef {
        return Bitcoin(name: name, code: code, symbol: symbol, colors: colors, state: state)
    }
}

/// Ethereum-compatible currency type
struct Ethereum: CurrencyDef {
    let baseUnit: Double = 1000000000000000000.0
    let name: String
    let code: String
    let symbol: String
    let colors: (UIColor, UIColor)
    let state: CurrencyState

    func mutate(state: CurrencyState) -> CurrencyDef {
        return Ethereum(name: name, code: code, symbol: symbol, colors: colors, state: state)
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
    let state: CurrencyState

    func mutate(state: CurrencyState) -> CurrencyDef {
        return ERC20Token(name: name, code: code, symbol: symbol, address: address, decimals: decimals, abi: abi, colors: colors, state: state)
    }
}

// TODO: cleanup
typealias Token = ERC20Token

// MARK: Instances

struct Currencies {
    static let btc = Bitcoin(name: "Bitcoin",
                             code: "BTC",
                             symbol: S.Symbols.btc,
                             colors: (UIColor(red:0.972549, green:0.623529, blue:0.200000, alpha:1.0), UIColor(red:0.898039, green:0.505882, blue:0.031373, alpha:1.0)),
                             state: CurrencyState.initial)
    static let bch = Bitcoin(name: "Bitcoin Cash",
                             code: "BCH",
                             symbol: S.Symbols.btc,
                             colors: (UIColor(red:0.278431, green:0.521569, blue:0.349020, alpha:1.0), UIColor(red:0.278431, green:0.521569, blue:0.349020, alpha:1.0)),
                             state: CurrencyState.initial)
    static let eth = Ethereum(name: "Ethereum",
                              code: "ETH",
                              symbol: S.Symbols.eth,
                              colors: (UIColor(red:0.407843, green:0.529412, blue:0.654902, alpha:1.0), UIColor(red:0.180392, green:0.278431, blue:0.376471, alpha:1.0)),
                              state: CurrencyState.initial)
    static let brd = ERC20Token(name: "Bread Token",
                                code: "BRD",
                                symbol: "🍞",
                                address: "0x558ec3152e2eb2174905cd19aea4e34a23de9ad6",
                                decimals: 18,
                                abi: "", //TODO - add erc20 abi
                                colors: (UIColor(red:0.95, green:0.65, blue:0.00, alpha:1.0), UIColor(red:0.95, green:0.35, blue:0.13, alpha:1.0)),
                                state: CurrencyState.initial)
}
