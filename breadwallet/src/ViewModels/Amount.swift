//
//  Amount.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-01-15.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation
import BRCrypto

public struct Amount {
    static let normalPrecisionDigits = 5
    static let highPrecisionDigits = 8

    let currency: Currency
    let core: BRCrypto.Amount
    var rate: Rate?
    var minimumFractionDigits: Int?
    var maximumFractionDigits: Int
    var negative: Bool { return core.isNegative }
    var isZero: Bool { return core == BRCrypto.Amount.create(integer: 0, unit: core.unit) }

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
    
    init(tokenString: String,
         currency: Currency,
         locale: Locale = Locale.current,
         unit: CurrencyUnit? = nil,
         rate: Rate? = nil,
         minimumFractionDigits: Int? = nil,
         maximumFractionDigits: Int = Amount.normalPrecisionDigits,
         negative: Bool = false) {
        let unit = (unit ?? currency.defaultUnit).core
        self.core = BRCrypto.Amount.create(string: tokenString.usDecimalString(fromLocale: locale),
                                           negative: negative,
                                           unit: unit)
            ?? BRCrypto.Amount.create(integer: 0, unit: currency.baseUnit.core)
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

    static func zero(_ currency: Currency, rate: Rate? = nil) -> Amount {
        return Amount(tokenString: "0", currency: currency, rate: rate)
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
    /// NB: Decimal can only represent maximum 38 digits wheras UInt256 can represent up to 78 digits -- it is assumed the units represented will be multiple orders of magnitude smaller than the base unit value and precision loss is acceptable.
    var tokenValue: Decimal {
        return Decimal(string: tokenUnformattedString(in: currency.defaultUnit)) ?? Decimal.zero
    }
    
    /// Token value in default units as formatted string with currency ticker symbol suffix
    var tokenDescription: String {
        return tokenDescription(in: currency.defaultUnit)
    }

    /// Token value in default units as formatted string without symbol
    var tokenFormattedString: String {
        return tokenFormattedString(in: currency.defaultUnit)
    }
    
    /// Token value in specified units as formatted string without symbol (for user display)
    func tokenFormattedString(in unit: CurrencyUnit) -> String {
        guard var formattedValue = core.string(as: unit.core, formatter: tokenFormat) else {
            assertionFailure()
            return ""
        }
        // override precision digits if the value is too small to show
        if !isZero && tokenFormat.number(from: formattedValue) == 0.0 {
            guard let formatter = tokenFormat.copy() as? NumberFormatter else { assertionFailure(); return "" }
            formatter.maximumFractionDigits = unit.decimals
            formattedValue = core.string(as: unit.core, formatter: formatter) ?? formattedValue
        }
        return formattedValue
    }

    /// Token value in specified units as unformatted string without symbol (used API/internal use)
    func tokenUnformattedString(in unit: CurrencyUnit) -> String {
        if unit == currency.baseUnit {
            return core.string(base: 10, preface: "")
        }
        guard let str = core.string(as: unit.core, formatter: rawTokenFormat) else {
            assertionFailure(); return ""
        }
        return str
    }
    
    /// Token value in specified units as formatted string with currency ticker symbol suffix
    func tokenDescription(in unit: CurrencyUnit) -> String {
        return "\(tokenFormattedString(in: unit)) \(currency.name(forUnit: unit))"
    }
    
    var tokenFormat: NumberFormatter {
        let format = NumberFormatter()
        format.isLenient = true
        format.numberStyle = .currency
        format.generatesDecimalNumbers = true
        format.negativeFormat = "-\(format.positiveFormat!)"
        format.currencyCode = currency.code
        format.currencySymbol = ""
        format.maximumFractionDigits = min(currency.defaultUnit.decimals, maximumFractionDigits)
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
    public static func == (lhs: Amount, rhs: Amount) -> Bool {
        return lhs.core == rhs.core /*&&
        lhs.rate == rhs.rate &&
        lhs.maximumFractionDigits == rhs.maximumFractionDigits &&
        lhs.minimumFractionDigits == rhs.minimumFractionDigits*/
    }

    public static func > (lhs: Amount, rhs: Amount) -> Bool {
        return lhs.core > rhs.core
    }

    public static func < (lhs: Amount, rhs: Amount) -> Bool {
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

struct CurrencyUnit: Equatable {
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

extension String {
    func usDecimalString(fromLocale inputLocale: Locale) -> String {
        let expectedFormat = NumberFormatter()
        expectedFormat.numberStyle = .decimal
        expectedFormat.locale = Locale(identifier: "en_US")

        // createUInt256ParseDecimal expects en_us formatted string
        let inputFormat = NumberFormatter()
        inputFormat.locale = inputLocale

        // remove grouping separators
        var sanitized = self.replacingOccurrences(of: inputFormat.currencyGroupingSeparator, with: "")
        sanitized = sanitized.replacingOccurrences(of: inputFormat.groupingSeparator, with: "")

        // replace decimal separators
        sanitized = sanitized.replacingOccurrences(of: inputFormat.currencyDecimalSeparator, with: expectedFormat.decimalSeparator)
        sanitized = sanitized.replacingOccurrences(of: inputFormat.decimalSeparator, with: expectedFormat.decimalSeparator)

        // createUInt256ParseDecimal does not accept integers
        if !sanitized.contains(expectedFormat.decimalSeparator) {
            sanitized += expectedFormat.decimalSeparator
        }

        return sanitized
    }
}
