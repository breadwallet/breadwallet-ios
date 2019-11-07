//
//  Amount.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-01-15.
//  Copyright © 2017-2019 Breadwinner AG. All rights reserved.
//

import Foundation
import BRCrypto

typealias CryptoAmount = BRCrypto.Amount

/// View model for representing the BRCrypto.Amount model
/// with extended currency, fiat conversion and formatting information
public struct Amount {
    static let normalPrecisionDigits = 5
    static let highPrecisionDigits = 8

    let currency: Currency
    let cryptoAmount: CryptoAmount
    var rate: Rate?
    var minimumFractionDigits: Int?
    var maximumFractionDigits: Int
    var negative: Bool { return cryptoAmount.isNegative }
    var isZero: Bool { return self == Amount.zero(currency, rate: rate) }
    internal var locale = Locale.current // for testing

    // MARK: - Init

    init(cryptoAmount: CryptoAmount,
         currency: Currency,
         rate: Rate? = nil,
         minimumFractionDigits: Int? = nil,
         maximumFractionDigits: Int = Amount.normalPrecisionDigits) {
        assert(currency.uid == cryptoAmount.currency.uid)
        self.currency = currency
        // make a new instance of CryptoAmount
        self.cryptoAmount = CryptoAmount.create(string: cryptoAmount.string(),
                                                negative: cryptoAmount.isNegative,
                                                unit: cryptoAmount.unit.base)
            ?? BRCrypto.Amount.create(integer: 0, unit: cryptoAmount.unit.base)
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
        // make a new instance of CryptoAmount
        self.cryptoAmount = CryptoAmount.create(string: amount.cryptoAmount.string(),
                                                negative: negative,
                                                unit: amount.currency.baseUnit)
            ?? BRCrypto.Amount.create(integer: 0, unit: amount.currency.baseUnit)
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
        let unit = (unit ?? currency.defaultUnit)
        self.cryptoAmount = CryptoAmount.create(string: tokenString.usDecimalString(fromLocale: locale),
                                                negative: negative,
                                                unit: unit)
            ?? BRCrypto.Amount.create(integer: 0, unit: currency.baseUnit)
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
        self.cryptoAmount = BRCrypto.Amount.create(double: decimal.doubleValue, unit: currency.defaultUnit)
        self.rate = rate
        self.minimumFractionDigits = minimumFractionDigits
        self.maximumFractionDigits = maximumFractionDigits
    }

    static func zero(_ currency: Currency, rate: Rate? = nil) -> Amount {
        return Amount(cryptoAmount: CryptoAmount.create(integer: 0, unit: currency.baseUnit),
                      currency: currency,
                      rate: rate)
    }

    // MARK: - Convenience Accessors
    
    var description: String {
        return rate != nil ? fiatDescription : tokenDescription
    }

    var combinedDescription: String {
        return Store.state.showFiatAmounts ? "\(fiatDescription) (\(tokenDescription))" : "\(tokenDescription) (\(fiatDescription))"
    }
    
    // MARK: Token
    
    /// Token value in default units as Decimal number
    /// NB: Decimal can only represent maximum 38 digits wheras UInt256 can represent up to 78 digits -- it is assumed the units represented will be multiple orders of magnitude smaller than the base unit value and precision loss is acceptable.
    var tokenValue: Decimal {
        return rawTokenFormat.number(from: tokenUnformattedString(in: currency.defaultUnit))?.decimalValue ?? Decimal.zero
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
        guard var formattedValue = cryptoAmount.string(as: unit, formatter: tokenFormat) else {
            assertionFailure()
            return ""
        }
        // override precision digits if the value is too small to show
        if !isZero && tokenFormat.number(from: formattedValue) == 0.0 {
            guard let formatter = tokenFormat.copy() as? NumberFormatter else { assertionFailure(); return "" }
            formatter.maximumFractionDigits = Int(unit.decimals)
            formattedValue = cryptoAmount.string(as: unit, formatter: formatter) ?? formattedValue
        }
        return formattedValue
    }

    /// Token value in specified units as unformatted string without symbol (used API/internal use)
    func tokenUnformattedString(in unit: CurrencyUnit) -> String {
        if unit == currency.baseUnit {
            return cryptoAmount.string(base: 10, preface: "")
        }
        guard let str = cryptoAmount.string(as: unit, formatter: rawTokenFormat) else {
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
        format.locale = locale
        format.isLenient = true
        format.numberStyle = .currency
        format.generatesDecimalNumbers = true
        format.negativeFormat = "-\(format.positiveFormat!)"
        format.currencyCode = currency.code
        format.currencySymbol = ""
        format.maximumFractionDigits = min(Int(currency.defaultUnit.decimals), maximumFractionDigits)
        format.minimumFractionDigits = minimumFractionDigits ?? 0
        return format
    }

    /// formatter for raw value with maximum precision and no symbols or separators
    private var rawTokenFormat: NumberFormatter {
        let format = NumberFormatter()
        format.locale = locale
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
        return value * Decimal(rate.rate)
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
        format.locale = locale
        format.isLenient = true
        format.numberStyle = .currency
        format.generatesDecimalNumbers = true
        format.negativeFormat = "-\(format.positiveFormat!)"
        if let rate = rate {
            format.currencySymbol = rate.currencySymbol
            format.maximumFractionDigits = rate.maxFractionalDigits
        } else if let rate = currency.state?.currentRate {
            format.currencySymbol = rate.currencySymbol
            format.maximumFractionDigits = rate.maxFractionalDigits
        }
        format.minimumFractionDigits = minimumFractionDigits ?? format.minimumFractionDigits
        return format
    }
    
    // MARK: - Private
    
    private var commonUnitValue: Decimal? {
        let commonUnitString = cryptoAmount.string(as: currency.defaultUnit, formatter: rawTokenFormat) ?? ""
        return rawTokenFormat.number(from: commonUnitString)?.decimalValue
    }
}

extension Amount: Equatable, Comparable {
    public static func == (lhs: Amount, rhs: Amount) -> Bool {
        return lhs.cryptoAmount == rhs.cryptoAmount
    }

    public static func > (lhs: Amount, rhs: Amount) -> Bool {
        return lhs.cryptoAmount > rhs.cryptoAmount
    }

    public static func < (lhs: Amount, rhs: Amount) -> Bool {
        return lhs.cryptoAmount < rhs.cryptoAmount
    }

    static func - (lhs: Amount, rhs: Amount) -> Amount {
        return Amount(cryptoAmount: (lhs.cryptoAmount - rhs.cryptoAmount) ?? lhs.cryptoAmount,
                      currency: lhs.currency,
                      rate: lhs.rate,
                      minimumFractionDigits: lhs.minimumFractionDigits,
                      maximumFractionDigits: lhs.maximumFractionDigits)
    }

    static func + (lhs: Amount, rhs: Amount) -> Amount {
        return Amount(cryptoAmount: (lhs.cryptoAmount + rhs.cryptoAmount) ?? lhs.cryptoAmount,
                      currency: lhs.currency,
                      rate: lhs.rate,
                      minimumFractionDigits: lhs.minimumFractionDigits,
                      maximumFractionDigits: lhs.maximumFractionDigits)
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

        return sanitized
    }
}
