//
//  Amount.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-01-15.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation
import BRCore

struct Amount {
    let amount: UInt256
    let currency: CurrencyDef
    let rate: Rate?
    let minimumFractionDigits: Int?
    let negative: Bool
    
    //TODO:ETH
    var rawValue: UInt256 { return amount }
    
    init(amount: UInt256, currency: CurrencyDef, rate: Rate? = nil, minimumFractionDigits: Int? = nil, negative: Bool = false) {
        self.amount = amount
        self.currency = currency
        self.rate = rate
        self.minimumFractionDigits = minimumFractionDigits
        self.negative = negative
    }
    
    init(string: String, currency: CurrencyDef, unit: CurrencyUnit? = nil, rate: Rate? = nil, minimumFractionDigits: Int? = nil, negative: Bool = false) {
        var decimals = currency.commonUnit.decimals
        if let unit = unit {
            decimals = unit.decimals
        }
        self.amount = UInt256(string: string, decimals: decimals)
        self.currency = currency
        self.rate = rate
        self.minimumFractionDigits = minimumFractionDigits
        self.negative = negative
    }
    
    var description: String {
        return rate != nil ? fiatDescription : tokenDescription
    }

    var combinedDescription: String {
        return Store.state.isBtcSwapped ? "\(fiatDescription) (\(tokenDescription))" : "\(tokenDescription) (\(fiatDescription))"
    }
    
    var tokenValue: Decimal {
        return Decimal(string: amount.string(decimals: currency.state.maxDigits)) ?? 0.0
    }
    
    var fiatValue: Decimal {
        guard let rate = rate ?? currency.state.currentRate,
            let value = commonUnitValue else { return 0.0 }
        let tokenAmount = value * (negative ? -1.0 : 1.0)
        return tokenAmount * Decimal(rate.rate)
    }

    var fiatDescription: String {
        guard let string = localFormat.string(from: fiatValue as NSNumber) else { return "" }
        return string
    }
    
    func fiatDescription(forLocale locale: Locale) -> String {
        let formatter = localFormat
        formatter.locale = locale
        guard let string = formatter.string(from: fiatValue as NSNumber) else { return "" }
        return string
    }

    var tokenDescription: String {
        let unit = currency.unit(forDecimals: currency.state.maxDigits) ?? currency.commonUnit
        return tokenDescription(inUnit: unit)
    }
    
    func tokenDescription(inUnit unit: CurrencyUnit) -> String {
        var value = Decimal(string: amount.string(decimals: unit.decimals)) ?? 0.0
        if negative {
            value *= -1.0
        }
        guard let formattedValue = tokenFormat.string(from: value as NSDecimalNumber) else { return "" }
        let symbol = currency.name(forUnit: unit)
        return "\(formattedValue) \(symbol)"
    }

    var localFormat: NumberFormatter {
        let format = NumberFormatter()
        format.isLenient = true
        format.numberStyle = .currency
        format.generatesDecimalNumbers = true
        format.negativeFormat = "-\(format.positiveFormat!)"
        if let rate = rate {
            format.currencySymbol = rate.currencySymbol
        } else if let rate = currency.state.currentRate {
            format.currencySymbol = rate.currencySymbol
        }
        if let minimumFractionDigits = minimumFractionDigits {
            format.minimumFractionDigits = minimumFractionDigits
        }
        return format
    }

    var tokenFormat: NumberFormatter {
        let format = NumberFormatter()
        format.isLenient = true
        format.numberStyle = .currency
        format.generatesDecimalNumbers = true
        format.negativeFormat = "-\(format.positiveFormat!)"
        format.currencyCode = currency.code
        format.currencySymbol = ""
        format.maximumFractionDigits = currency.state.maxDigits
        format.minimumFractionDigits = minimumFractionDigits ?? 0
        return format
    }
    
    private var commonUnitString: String {
        return amount.string(decimals: currency.commonUnit.decimals)
    }
    
    private var commonUnitValue: Decimal? {
        return Decimal(string: commonUnitString)
    }
}
