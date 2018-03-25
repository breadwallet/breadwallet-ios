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
    
    init(amount: UInt256, currency: CurrencyDef, rate: Rate? = nil, minimumFractionDigits: Int? = nil, negative: Bool = false) {
        self.amount = amount
        self.rate = rate
        self.minimumFractionDigits = minimumFractionDigits
        self.currency = currency
        self.negative = negative
    }
    
    var description: String {
        return rate != nil ? fiatDescription : tokenDescription
    }

    var combinedDescription: String {
        return Store.state.isBtcSwapped ? "\(fiatDescription) (\(tokenDescription))" : "\(tokenDescription) (\(fiatDescription))"
    }
    
    var tokenValue: Double {
        let str = amount.string(decimals: currency.state.maxDigits)
        return Double(str) ?? -1.0
    }
    
    var fiatValue: Double {
        guard let rate = rate ?? currency.state.currentRate,
            let value = commonUnitValue else { return 0.0 }
        let tokenAmount = value * (negative ? -1.0 : 1.0)
        return tokenAmount * rate.rate
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
        let decimal = Decimal(tokenValue)
        let number = NSDecimalNumber(decimal: decimal * (negative ? -1.0 : 1.0))
        guard let amount = tokenFormat.string(from: number) else { return "" }
        let unit = currency.unitName(forDecimals: currency.state.maxDigits)
        return "\(amount) \(unit)"
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
    
    private var commonUnitValue: Double? {
        // NB: assumes common units are small enough to fit a  Double
        return Double(commonUnitString)
    }
}
