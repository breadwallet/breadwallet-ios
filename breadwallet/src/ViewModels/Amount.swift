//
//  Amount.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-01-15.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation

struct Amount {

    //MARK: - Public
    let amount: UInt64 //amount in satoshis
    let rate: Rate
    let maxDigits: Int
    let currency: CurrencyDef
    
    var amountForBtcFormat: Double {
        var decimal = Decimal(self.amount)
        var amount: Decimal = 0.0
        NSDecimalMultiplyByPowerOf10(&amount, &decimal, Int16(-maxDigits), .up)
        return NSDecimalNumber(decimal: amount).doubleValue
    }

    var localAmount: Double {
        return Double(amount)/currency.baseUnit*rate.rate
    }

    var bits: String {
        var decimal = Decimal(self.amount)
        var amount: Decimal = 0.0
        NSDecimalMultiplyByPowerOf10(&amount, &decimal, Int16(-maxDigits), .up)
        let number = NSDecimalNumber(decimal: amount)
        guard let string = btcFormat.string(from: number) else { return "" }
        return string
    }

    var localCurrency: String {
        guard let string = localFormat.string(from: Double(amount)/currency.baseUnit*rate.rate as NSNumber) else { return "" }
        return string
    }

    func string(forLocal local: Locale) -> String {
        let format = NumberFormatter()
        format.locale = local
        format.isLenient = true
        format.numberStyle = .currency
        format.generatesDecimalNumbers = true
        format.negativeFormat = format.positiveFormat.replacingCharacters(in: format.positiveFormat.range(of: "#")!, with: "-#")
        guard let string = format.string(from: Double(amount)/currency.baseUnit*rate.rate as NSNumber) else { return "" }
        return string
    }

    func string(isBtcSwapped: Bool) -> String {
        return isBtcSwapped ? localCurrency : bits
    }

    var ethFormat: NumberFormatter {
        let format = NumberFormatter()
        format.isLenient = true
        format.numberStyle = .currency
        format.generatesDecimalNumbers = true
        format.negativeFormat = format.positiveFormat.replacingCharacters(in: format.positiveFormat.range(of: "#")!, with: "-#")
        format.currencyCode = "ETH"
        format.currencySymbol = "\(S.Symbols.eth)\(S.Symbols.narrowSpace)"
        format.maximumFractionDigits = 8
        format.minimumFractionDigits = 0
        return format
    }

    var btcFormat: NumberFormatter {
        let format = NumberFormatter()
        format.isLenient = true
        format.numberStyle = .currency
        format.generatesDecimalNumbers = true
        format.negativeFormat = format.positiveFormat.replacingCharacters(in: format.positiveFormat.range(of: "#")!, with: "-#")
        format.currencyCode = "XBT"

        switch maxDigits {
        case 2:
            format.currencySymbol = "\(S.Symbols.bits)\(S.Symbols.narrowSpace)"
            format.maximum = (C.maxMoney/C.satoshis)*100000 as NSNumber
        case 5:
            format.currencySymbol = "m\(S.Symbols.btc)\(S.Symbols.narrowSpace)"
            format.maximum = (C.maxMoney/C.satoshis)*1000 as NSNumber
        case 8:
            format.currencySymbol = "\(S.Symbols.btc)\(S.Symbols.narrowSpace)"
            format.maximum = C.maxMoney/C.satoshis as NSNumber
        default:
            format.currencySymbol = "\(S.Symbols.bits)\(S.Symbols.narrowSpace)"
        }

        format.maximumFractionDigits = maxDigits
        format.minimumFractionDigits = 0 // iOS 8 bug, minimumFractionDigits now has to be set after currencySymbol
        format.maximum = Decimal(C.maxMoney)/(pow(10.0, maxDigits)) as NSNumber

        return format
    }

    var localFormat: NumberFormatter {
        let format = NumberFormatter()
        format.isLenient = true
        format.numberStyle = .currency
        format.generatesDecimalNumbers = true
        format.negativeFormat = format.positiveFormat.replacingCharacters(in: format.positiveFormat.range(of: "#")!, with: "-#")
        format.currencySymbol = rate.currencySymbol
        return format
    }
}

// TODO:BCH conslidate DisplayAmount + Amount
struct DisplayAmount {
    let amount: Satoshis
    let selectedRate: Rate?
    let minimumFractionDigits: Int?
    let currency: CurrencyDef
    let negative: Bool
    
    init(amount: Satoshis, selectedRate: Rate?, minimumFractionDigits: Int?, currency: CurrencyDef, negative: Bool) {
        self.amount = amount
        self.selectedRate = selectedRate
        self.minimumFractionDigits = minimumFractionDigits
        self.currency = currency
        self.negative = negative
    }
    
    init(amount: Satoshis, selectedRate: Rate?, minimumFractionDigits: Int?, currency: CurrencyDef) {
        self.init(amount: amount, selectedRate: selectedRate, minimumFractionDigits: minimumFractionDigits, currency: currency, negative: false)
    }
    
    var description: String {
        return selectedRate != nil ? fiatDescription : bitcoinDescription
    }

    var combinedDescription: String {
        return Store.state.isBtcSwapped ? "\(fiatDescription) (\(bitcoinDescription))" : "\(bitcoinDescription) (\(fiatDescription))"
    }

    private var fiatDescription: String {
        guard let rate = selectedRate ?? currency.state.currentRate else { return "" }
        let tokenAmount = Double(amount.rawValue) * (negative ? -1.0 : 1.0)
        guard let string = localFormat.string(from: tokenAmount/currency.baseUnit*rate.rate as NSNumber) else { return "" }
        return string
    }

    private var bitcoinDescription: String {
        var decimal = Decimal(self.amount.rawValue)
        var amount: Decimal = 0.0
        NSDecimalMultiplyByPowerOf10(&amount, &decimal, Int16(-currency.state.maxDigits), .up)
        let number = NSDecimalNumber(decimal: amount * (negative ? -1.0 : 1.0))
        guard let string = btcFormat.string(from: number) else { return "" }
        return string
    }

    var localFormat: NumberFormatter {
        let format = NumberFormatter()
        format.isLenient = true
        format.numberStyle = .currency
        format.generatesDecimalNumbers = true
        format.negativeFormat = "-\(format.positiveFormat!)"
        if let rate = selectedRate {
            format.currencySymbol = rate.currencySymbol
        } else if let rate = currency.state.currentRate {
            format.currencySymbol = rate.currencySymbol
        }
        if let minimumFractionDigits = minimumFractionDigits {
            format.minimumFractionDigits = minimumFractionDigits
        }
        return format
    }

    var btcFormat: NumberFormatter {
        let format = NumberFormatter()
        format.isLenient = true
        format.numberStyle = .currency
        format.generatesDecimalNumbers = true
        format.negativeFormat = "-\(format.positiveFormat!)"
        format.currencyCode = currency.code
        switch currency.state.maxDigits {
        case 2:
            format.currencySymbol = "\(S.Symbols.bits)\(S.Symbols.narrowSpace)"
            format.maximum = (C.maxMoney/C.satoshis)*100000 as NSNumber
        case 5:
            format.currencySymbol = "m\(S.Symbols.btc)\(S.Symbols.narrowSpace)"
            format.maximum = (C.maxMoney/C.satoshis)*1000 as NSNumber
        case 8:
            format.currencySymbol = "\(S.Symbols.btc)\(S.Symbols.narrowSpace)"
            format.maximum = C.maxMoney/C.satoshis as NSNumber
        default:
            format.currencySymbol = "\(S.Symbols.bits)\(S.Symbols.narrowSpace)"
        }

        format.maximumFractionDigits = currency.state.maxDigits
        format.maximum = Decimal(C.maxMoney)/(pow(10.0, currency.state.maxDigits)) as NSNumber

        if let minimumFractionDigits = minimumFractionDigits {
            format.minimumFractionDigits = minimumFractionDigits
        }

        return format
    }

    // TODO:BCH cleanup
    static func ethString(value: GethBigInt) -> String {
        guard let rate = Currencies.eth.state.currentRate else { return "" }
        let placeholderAmount = Amount(amount: 0, rate: rate, maxDigits: 0, currency: Currencies.eth)
        var decimal = Decimal(string: value.getString(10)) ?? Decimal(0)
        var amount: Decimal = 0.0
        NSDecimalMultiplyByPowerOf10(&amount, &decimal, Int16(-18), .up)
        let eth = NSDecimalNumber(decimal: amount)
        return placeholderAmount.ethFormat.string(from: eth) ?? ""
    }

    static func localEthString(value: GethBigInt) -> String {
        guard let rate = Currencies.eth.state.currentRate else { return "" }
        let placeholderAmount = Amount(amount: 0, rate: rate, maxDigits: 0, currency: Currencies.eth)
        var decimal = Decimal(string: value.getString(10)) ?? Decimal(0)
        var amount: Decimal = 0.0
        NSDecimalMultiplyByPowerOf10(&amount, &decimal, Int16(-18), .up)
        let eth = NSDecimalNumber(decimal: amount)
        return placeholderAmount.localFormat.string(for: eth.doubleValue*rate.rate) ?? ""
    }
}
