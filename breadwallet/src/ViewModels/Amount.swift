//
//  Amount.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-01-15.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation
import BRCore
import BRCrypto

//TODO:CRYPTO
// swiftlint:disable all


struct Amount {
    static let normalPrecisionDigits = 5
    static let highPrecisionDigits = 8

    let currency: Currency
    let core: BRCrypto.Amount
    var rate: Rate?
    var minimumFractionDigits: Int?
    var maximumFractionDigits: Int
    var negative: Bool { return core.isNegative }
    var isZero: Bool { return core == BRCrypto.Amount.create(integer: 0, unit: core.unit) }

    //TODO:CRYPTO deprecate usage
    var rawValue: UInt256 {
        guard let baseUnitString = core.string(as: currency.baseUnit.core, formatter: rawTokenFormat) else { return UInt256(0) }
        return UInt256(string: baseUnitString)
    }
    
    // MARK: - Init

    init(coreAmount: BRCrypto.Amount,
         currency: Currency,
         rate: Rate? = nil,
         minimumFractionDigits: Int? = nil,
         maximumFractionDigits: Int = Amount.normalPrecisionDigits) {
        self.currency = currency
        self.core = coreAmount
        self.rate = rate
        self.minimumFractionDigits = minimumFractionDigits
        self.maximumFractionDigits = maximumFractionDigits
    }

    init(amount: Amount,
         rate: Rate? = nil,
         minimumFractionDigits: Int? = nil,
         maximumFractionDigits: Int? = nil,
         negative: Bool = false) {
        self.currency = amount.currency
        self.core = negative ? amount.core.negate : amount.core
        self.rate = rate ?? amount.rate
        self.minimumFractionDigits = minimumFractionDigits ?? amount.minimumFractionDigits
        self.maximumFractionDigits = maximumFractionDigits ?? amount.maximumFractionDigits
    }
    
    init(value: UInt256,
         currency: Currency,
         rate: Rate? = nil,
         minimumFractionDigits: Int? = nil,
         maximumFractionDigits: Int = Amount.normalPrecisionDigits,
         negative: Bool = false) {
        let amountString = value.string(radix: 10)
        self.core = BRCrypto.Amount.create(string: amountString, negative: negative, unit: currency.baseUnit.core) ?? BRCrypto.Amount.create(integer: 0, unit: currency.baseUnit.core)
        self.currency = currency
        self.rate = rate
        self.minimumFractionDigits = minimumFractionDigits
        self.maximumFractionDigits = maximumFractionDigits
    }
    
    init(tokenString: String,
         currency: Currency,
         locale: Locale = Locale.current,
         unit: CurrencyUnit? = nil,
         rate: Rate? = nil,
         minimumFractionDigits: Int? = nil,
         maximumFractionDigits: Int = Amount.normalPrecisionDigits,
         negative: Bool = false) {
        let unit = (unit ?? currency.defaultUnit).core
        self.core = BRCrypto.Amount.create(string: tokenString.usDecimalString(fromLocale: locale), negative: negative, unit: unit) ?? BRCrypto.Amount.create(integer: 0, unit: currency.baseUnit.core)
        self.currency = currency
        self.rate = rate
        self.minimumFractionDigits = minimumFractionDigits
        self.maximumFractionDigits = maximumFractionDigits
    }
    
    init?(fiatString: String,
          currency: Currency,
          rate: Rate,
          minimumFractionDigits: Int? = nil,
          maximumFractionDigits: Int = Amount.normalPrecisionDigits,
          negative: Bool = false) {
        self.currency = currency
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = currency.defaultUnit.decimals
        formatter.minimumFractionDigits = 1
        formatter.minimumIntegerDigits = 1
        formatter.generatesDecimalNumbers = true
        formatter.usesGroupingSeparator = false
        formatter.locale = Locale(identifier: "en_US")
        //TODO:CRYPTO use BRCrypto CurrencyPair for conversion
        guard let fiatAmount = NumberFormatter().number(from: fiatString)?.decimalValue else { return nil }
        var decimal = fiatAmount / Decimal(rate.rate)
        if negative {
            decimal *= -1.0
        }
        self.core = BRCrypto.Amount.create(double: decimal.doubleValue, unit: currency.defaultUnit.core)
        self.rate = rate
        self.minimumFractionDigits = minimumFractionDigits
        self.maximumFractionDigits = maximumFractionDigits
    }

    static func zero(_ currency: Currency) -> Amount {
        return Amount(tokenString: "0", currency: currency)
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
        //TODO:CRYPTO this no longer supports arbitrary (user-defined) unit
        //TODO:CRYPTO Amount.string(as:) converts to Double first so not sure Decimal preserves any additional precision here
        //return (Decimal(string: amount.string(decimals: currency.state?.maxDigits ?? currency.commonUnit.decimals)) ?? 0.0) * (negative ? -1.0 : 1.0)
        return Decimal(string: core.string(as: currency.defaultUnit.core, formatter: rawTokenFormat) ?? "") ?? Decimal.zero
    }
    
    /// Token value in default units as formatted string with currency ticker symbol suffix
    var tokenDescription: String {
        //TODO:CRYPTO this no longer supports arbitrary (user-defined) unit
        let unit = currency.defaultUnit//let unit = currency.unit(forDecimals: currency.state?.maxDigits ?? currency.commonUnit.decimals) ?? currency.commonUnit
        return tokenDescription(in: unit)
    }
    
    /// Token value in default units as formatted string without symbol
    var tokenFormattedValue: String {
        //TODO:CRYPTO this no longer supports arbitrary (user-defined) unit
        let unit = currency.defaultUnit//currency.unit(forDecimals: currency.state?.maxDigits ?? currency.commonUnit.decimals) ?? currency.commonUnit
        return tokenFormattedValue(inUnit: unit)
    }
    
    /// Token value in specified units as formatted string without symbol
    func tokenFormattedValue(inUnit unit: CurrencyUnit) -> String {
        var value = Decimal(string: core.string(as: unit.core, formatter: rawTokenFormat) ?? "") ?? 0.0
        if negative {
            value *= -1.0
        }
        guard var formattedValue = tokenFormat.string(from: value as NSDecimalNumber) else { return "" }
        if !isZero && Double(formattedValue) == 0.0 {
            // small value requires more precision to be displayed
            guard let formatter = tokenFormat.copy() as? NumberFormatter else { return "" }
            formatter.maximumFractionDigits = unit.decimals
            formattedValue = formatter.string(from: value as NSDecimalNumber) ?? formattedValue
        }
        return formattedValue
//        return core.string(as: unit.core, formatter: tokenFormat) ?? ""
    }
    
    /// Token value in specified units as formatted string with currency ticker symbol suffix
    func tokenDescription(in unit: CurrencyUnit) -> String {
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
        format.maximumFractionDigits = min(currency.state?.maxDigits ?? currency.defaultUnit.decimals, maximumFractionDigits)
        format.minimumFractionDigits = minimumFractionDigits ?? 0
        return format
    }

    /// formatter for raw value with maximum precision and no symbols or separators
    private var rawTokenFormat: NumberFormatter {
        let format = NumberFormatter()
        format.isLenient = true
        format.numberStyle = .currency
        format.generatesDecimalNumbers = true
        format.usesGroupingSeparator = false
        format.currencyCode = ""
        format.currencySymbol = ""
        format.maximumFractionDigits = 99
        format.minimumFractionDigits = 0
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
        return core.string(as: currency.defaultUnit.core, formatter: rawTokenFormat) ?? ""
    }
    
    private var commonUnitValue: Decimal? {
        return Decimal(string: commonUnitString)
    }
}

extension Amount: Equatable, Comparable {
    static func == (lhs: Amount, rhs: Amount) -> Bool {
        return lhs.core == rhs.core /*&&
        lhs.rate == rhs.rate &&
        lhs.maximumFractionDigits == rhs.maximumFractionDigits &&
        lhs.minimumFractionDigits == rhs.minimumFractionDigits*/
    }

    static func > (lhs: Amount, rhs: Amount) -> Bool {
        return lhs.core > rhs.core
    }

    static func < (lhs: Amount, rhs: Amount) -> Bool {
        return lhs.core < rhs.core
    }

    static func - (lhs: Amount, rhs: Amount) -> Amount {
        //TODO:CRYPTO
        return Amount(coreAmount: (lhs.core - rhs.core) ?? lhs.core,
                      currency: lhs.currency,
                      rate: lhs.rate,
                      minimumFractionDigits: lhs.minimumFractionDigits,
                      maximumFractionDigits: lhs.maximumFractionDigits)
    }

    static func + (lhs: Amount, rhs: Amount) -> Amount {
        //TODO:CRYPTO
        return Amount(coreAmount: (lhs.core + rhs.core) ?? lhs.core,
                      currency: lhs.currency,
                      rate: lhs.rate,
                      minimumFractionDigits: lhs.minimumFractionDigits,
                      maximumFractionDigits: lhs.maximumFractionDigits)
    }
}

struct CurrencyUnit {
    fileprivate let core: BRCrypto.Unit

    var decimals: Int { return Int(core.decimals) }
    var name: String { return core.name }

    init(core: BRCrypto.Unit) {
        self.core = core
    }
}

extension Decimal {
    var doubleValue: Double {
        return NSDecimalNumber(decimal: self).doubleValue
    }
}
