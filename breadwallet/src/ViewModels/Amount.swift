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
    static let normalPrecisionDigits = 5
    static let highPrecisionDigits = 8
    
    let amount: UInt256
    let currency: Currency
    let rate: Rate?
    let minimumFractionDigits: Int?
    let maximumFractionDigits: Int
    let negative: Bool
    
    var rawValue: UInt256 { return amount }
    
    // MARK: - Init
    
    init(amount: UInt256,
         currency: Currency,
         rate: Rate? = nil,
         minimumFractionDigits: Int? = nil,
         maximumFractionDigits: Int = Amount.normalPrecisionDigits,
         negative: Bool = false) {
        self.amount = amount
        self.currency = currency
        self.rate = rate
        self.minimumFractionDigits = minimumFractionDigits
        self.maximumFractionDigits = maximumFractionDigits
        self.negative = negative
    }
    
    init(tokenString: String,
         currency: Currency,
         locale: Locale = Locale.current,
         unit: CurrencyUnit? = nil,
         rate: Rate? = nil,
         minimumFractionDigits: Int? = nil,
         maximumFractionDigits: Int = Amount.normalPrecisionDigits,
         negative: Bool = false) {
        let decimals = unit?.decimals ?? currency.commonUnit.decimals
        self.amount = UInt256(string: tokenString.usDecimalString(fromLocale: locale), decimals: decimals)
        self.currency = currency
        self.rate = rate
        self.minimumFractionDigits = minimumFractionDigits
        self.maximumFractionDigits = maximumFractionDigits
        self.negative = negative
    }
    
    init?(fiatString: String,
          currency: Currency,
          rate: Rate,
          minimumFractionDigits: Int? = nil,
          maximumFractionDigits: Int = Amount.normalPrecisionDigits,
          negative: Bool = false) {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = currency.commonUnit.decimals
        formatter.minimumFractionDigits = 1
        formatter.minimumIntegerDigits = 1
        formatter.generatesDecimalNumbers = true
        formatter.usesGroupingSeparator = false
        formatter.locale = Locale(identifier: "en_US")
        guard let fiatAmount = NumberFormatter().number(from: fiatString)?.decimalValue,
            let commonUnitString = formatter.string(from: (fiatAmount / Decimal(rate.rate)) as NSDecimalNumber) else { return nil }
        
        self.amount = UInt256(string: commonUnitString, decimals: currency.commonUnit.decimals)
        self.currency = currency
        self.rate = rate
        self.minimumFractionDigits = minimumFractionDigits
        self.maximumFractionDigits = maximumFractionDigits
        self.negative = negative
    }
    
    static var empty: Amount {
        return Amount(amount: UInt256(0), currency: Currencies.btc)
    }
    
    // MARK: - Convenience Accessors
    
    var description: String {
        return rate != nil ? fiatDescription : tokenDescription
    }

    var combinedDescription: String {
        return Store.state.isBtcSwapped ? "\(fiatDescription) (\(tokenDescription))" : "\(tokenDescription) (\(fiatDescription))"
    }
    
    // MARK: Token
    
    /// Token value in default units as Decimal number
    /// NB: Decimal can only represent maximum 38 digits wheras UInt256 can represent up to 78 digits -- it is assumed the units represented will be multiple orders of magnitude smaller than the raw value and precision loss is acceptable.
    var tokenValue: Decimal {
        return (Decimal(string: amount.string(decimals: currency.state?.maxDigits ?? currency.commonUnit.decimals)) ?? 0.0) * (negative ? -1.0 : 1.0)
    }
    
    /// Token value in default units as formatted string with currency ticker symbol suffix
    var tokenDescription: String {
        let unit = currency.unit(forDecimals: currency.state?.maxDigits ?? currency.commonUnit.decimals) ?? currency.commonUnit
        return tokenDescription(inUnit: unit)
    }
    
    /// Token value in default units as formatted string without symbol
    var tokenFormattedValue: String {
        let unit = currency.unit(forDecimals: currency.state?.maxDigits ?? currency.commonUnit.decimals) ?? currency.commonUnit
        return tokenFormattedValue(inUnit: unit)
    }
    
    /// Token value in specified units as formatted string without symbol
    func tokenFormattedValue(inUnit unit: CurrencyUnit) -> String {
        var value = Decimal(string: amount.string(decimals: unit.decimals)) ?? 0.0
        if negative {
            value *= -1.0
        }
        guard var formattedValue = tokenFormat.string(from: value as NSDecimalNumber) else { return "" }
        if amount > UInt256(0) && Double(formattedValue) == 0.0 {
            // small value requires more precision to be displayed
            guard let formatter = tokenFormat.copy() as? NumberFormatter else { return "" }
            formatter.maximumFractionDigits = unit.decimals
            formattedValue = formatter.string(from: value as NSDecimalNumber) ?? formattedValue
        }
        return formattedValue
    }
    
    /// Token value in specified units as formatted string with currency ticker symbol suffix
    func tokenDescription(inUnit unit: CurrencyUnit) -> String {
        return "\(tokenFormattedValue(inUnit: unit)) \(currency.name(forUnit: unit))"
    }
    
    var tokenFormat: NumberFormatter {
        let format = NumberFormatter()
        format.isLenient = true
        format.numberStyle = .currency
        format.generatesDecimalNumbers = true
        format.negativeFormat = "-\(format.positiveFormat!)"
        format.currencyCode = currency.code
        format.currencySymbol = ""
        format.maximumFractionDigits = min(currency.state?.maxDigits ?? currency.commonUnit.decimals, maximumFractionDigits)
        format.minimumFractionDigits = minimumFractionDigits ?? 0
        return format
    }

    // MARK: - Fiat
    
    var fiatValue: Decimal {
        guard let rate = rate ?? currency.state?.currentRate,
            let value = commonUnitValue else { return 0.0 }
        let tokenAmount = value * (negative ? -1.0 : 1.0)
        return tokenAmount * Decimal(rate.rate)
    }
    
    var fiatDescription: String {
        return fiatDescription()
    }
    
    func fiatDescription(forLocale locale: Locale? = nil) -> String {
        let formatter = localFormat
        if let locale = locale {
            formatter.locale = locale
        }
        guard var fiatString = formatter.string(from: fiatValue as NSDecimalNumber) else { return "" }
        if let stringValue = formatter.number(from: fiatString), abs(fiatValue) > 0.0, stringValue == 0 {
            // if non-zero values show as 0, show minimum fractional value for fiat
            let minimumValue = pow(10.0, Double(-formatter.minimumFractionDigits)) * (negative ? -1.0 : 1.0)
            fiatString = formatter.string(from: NSDecimalNumber(value: minimumValue)) ?? fiatString
        }
        return fiatString
    }
    
    var localFormat: NumberFormatter {
        let format = NumberFormatter()
        format.isLenient = true
        format.numberStyle = .currency
        format.generatesDecimalNumbers = true
        format.negativeFormat = "-\(format.positiveFormat!)"
        if let rate = rate {
            format.currencySymbol = rate.currencySymbol
        } else if let rate = currency.state?.currentRate {
            format.currencySymbol = rate.currencySymbol
        }
        format.minimumFractionDigits = minimumFractionDigits ?? format.minimumFractionDigits
        return format
    }
    
    // MARK: - Private
    
    private var commonUnitString: String {
        return amount.string(decimals: currency.commonUnit.decimals)
    }
    
    private var commonUnitValue: Decimal? {
        return Decimal(string: commonUnitString)
    }
}
