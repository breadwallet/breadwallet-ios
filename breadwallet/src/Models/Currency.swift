//
//  Currency.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2018-01-10.
//  Copyright © 2018 breadwallet LLC. All rights reserved.
//

import Foundation
import Geth
import BRCore

// MARK: - Protocols

/// Represents common properties of cryptocurrency types
protocol CurrencyDef {
    var code: String { get }
    var symbol: String { get }
    var name: String { get }
    var baseUnit: Double { get }
}

// MARK: - Currency Definitions

/// Bitcoin-compatible currency type
struct Bitcoin: CurrencyDef {
    let baseUnit = 100000000.0
    let name: String
    let code: String
    let symbol: String
}

/// Ethereum-compatible currency type
struct Ethereum: CurrencyDef {
    let baseUnit: Double = 1000000000000000000.0
    let name: String
    let code: String
    let symbol: String
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
}

// TODO: cleanup
typealias Token = ERC20Token

// MARK: Instances

struct Currencies {
    static let btc = Bitcoin(name: "Bitcoin",
                             code: "BTC",
                             symbol: S.Symbols.btc)
    static let eth = Ethereum(name: "Ethereum",
                              code: "ETH",
                              symbol: S.Symbols.eth)
    static let brd = ERC20Token(name: "Bread Token",
                                code: "BRD",
                                symbol: "🍞",
                                address: "0x558ec3152e2eb2174905cd19aea4e34a23de9ad6",
                                decimals: 18,
                                abi: erc20ABI)
}
