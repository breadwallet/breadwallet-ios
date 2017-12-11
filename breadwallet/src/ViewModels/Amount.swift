//
//  Amount.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-01-15.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation
import Geth

struct Amount {

    //MARK: - Public
    let amount: UInt64 //amount in satoshis
    let rate: Rate
    let maxDigits: Int
    let store: Store
    
    var amountForBtcFormat: Double {
        var decimal = Decimal(self.amount)
        var amount: Decimal = 0.0
        if store.isEthLike {
            NSDecimalMultiplyByPowerOf10(&amount, &decimal, Int16(-18), .up)
        } else {
            NSDecimalMultiplyByPowerOf10(&amount, &decimal, Int16(-maxDigits), .up)
        }
        return NSDecimalNumber(decimal: amount).doubleValue
    }

    var localAmount: Double {
        return Double(amount)/store.state.currency.baseUnit*rate.rate
    }

    var bits: String {
        var decimal = Decimal(self.amount)
        var amount: Decimal = 0.0
        if store.isEthLike {
            NSDecimalMultiplyByPowerOf10(&amount, &decimal, Int16(-18), .up)
        } else {
            NSDecimalMultiplyByPowerOf10(&amount, &decimal, Int16(-maxDigits), .up)
        }
        let number = NSDecimalNumber(decimal: amount)
        guard let string = btcFormat.string(from: number) else { return "" }
        return string
    }

    var localCurrency: String {
        guard let string = localFormat.string(from: Double(amount)/store.state.currency.baseUnit*rate.rate as NSNumber) else { return "" }
        return string
    }

    func string(forLocal local: Locale) -> String {
        let format = NumberFormatter()
        format.locale = local
        format.isLenient = true
        format.numberStyle = .currency
        format.generatesDecimalNumbers = true
        format.negativeFormat = format.positiveFormat.replacingCharacters(in: format.positiveFormat.range(of: "#")!, with: "-#")
        guard let string = format.string(from: Double(amount)/store.state.currency.baseUnit*rate.rate as NSNumber) else { return "" }
        return string
    }

    func string(isBtcSwapped: Bool) -> String {
        return isBtcSwapped ? localCurrency : bits
    }

    var tokenFormat: NumberFormatter {
        let format = NumberFormatter()
        format.isLenient = true
        format.numberStyle = .currency
        format.generatesDecimalNumbers = true
        format.negativeFormat = format.positiveFormat.replacingCharacters(in: format.positiveFormat.range(of: "#")!, with: "-#")
        format.currencyCode = "store.state.walletState.token!.code"
        format.currencySymbol = "\(store.state.walletState.token!.code)"
        format.maximumFractionDigits = 8
        format.minimumFractionDigits = 0
        return format
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
        if store.isEthLike {
            let format = NumberFormatter()
            format.isLenient = true
            format.numberStyle = .currency
            format.generatesDecimalNumbers = true
            format.negativeFormat = format.positiveFormat.replacingCharacters(in: format.positiveFormat.range(of: "#")!, with: "-#")
            format.currencyCode = "ETH"
            if let crowdsale = store.state.walletState.crowdsale, !crowdsale.hasEnded {
                format.currencySymbol = "\(S.Symbols.eth)\(S.Symbols.narrowSpace)"
            } else if store.state.currency == .ethereum {
                format.currencySymbol = "\(S.Symbols.eth)\(S.Symbols.narrowSpace)"
            } else {
                format.currencySymbol = "\(store.state.walletState.token!.code) "
            }
            format.maximumFractionDigits = 8
            format.minimumFractionDigits = 0
            return format
        }
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

struct DisplayAmount {
    let amount: Satoshis
    let state: State
    let selectedRate: Rate?
    let minimumFractionDigits: Int?
    let store: Store

    var description: String {
        return selectedRate != nil ? fiatDescription : bitcoinDescription
    }

    var combinedDescription: String {
        return state.isBtcSwapped ? "\(fiatDescription) (\(bitcoinDescription))" : "\(bitcoinDescription) (\(fiatDescription))"
    }

    private var fiatDescription: String {
        guard let rate = selectedRate ?? state.currentRate else { return "" }
        guard let string = localFormat.string(from: Double(amount.rawValue)/store.state.currency.baseUnit*rate.rate as NSNumber) else { return "" }
        return string
    }

    private var bitcoinDescription: String {
        var decimal = Decimal(self.amount.rawValue)
        var amount: Decimal = 0.0
        if store.isEthLike {
            NSDecimalMultiplyByPowerOf10(&amount, &decimal, Int16(-18), .up)
        } else {
            NSDecimalMultiplyByPowerOf10(&amount, &decimal, Int16(-state.maxDigits), .up)
        }
        let number = NSDecimalNumber(decimal: amount)
        guard let string = btcFormat.string(from: number) else { return "" }
        return string
    }

    var localFormat: NumberFormatter {
        let format = NumberFormatter()
        format.isLenient = true
        format.numberStyle = .currency
        format.generatesDecimalNumbers = true
        format.negativeFormat = format.positiveFormat.replacingCharacters(in: format.positiveFormat.range(of: "#")!, with: "-#")
        if let rate = selectedRate {
            format.currencySymbol = rate.currencySymbol
        } else if let rate = state.currentRate {
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
        format.negativeFormat = format.positiveFormat.replacingCharacters(in: format.positiveFormat.range(of: "#")!, with: "-#")
        if store.isEthLike {
            if store.state.currency == .ethereum {
                format.currencyCode = "ETH"
                format.currencySymbol = "\(S.Symbols.eth)\(S.Symbols.narrowSpace)"
            } else {
                format.currencyCode = store.state.walletState.token!.code
                format.currencySymbol = "\(store.state.walletState.token!.code) "
            }
        } else {
            format.currencyCode = "XBT"
            switch state.maxDigits {
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

            format.maximumFractionDigits = state.maxDigits
            format.maximum = Decimal(C.maxMoney)/(pow(10.0, state.maxDigits)) as NSNumber
        }

        if let minimumFractionDigits = minimumFractionDigits {
            format.minimumFractionDigits = minimumFractionDigits
        }

        return format
    }

    static func ethString(value: GethBigInt, store: Store) -> String {
        let placeholderAmount = Amount(amount: 0, rate: store.state.currentRate!, maxDigits: 0, store: store)
        var decimal = Decimal(string: value.getString(10)) ?? Decimal(0)
        var amount: Decimal = 0.0
        NSDecimalMultiplyByPowerOf10(&amount, &decimal, Int16(-18), .up)
        let eth = NSDecimalNumber(decimal: amount)
        return placeholderAmount.ethFormat.string(from: eth) ?? ""
    }

    static func tokenString(value: GethBigInt, store: Store) -> String {
        let placeholderAmount = Amount(amount: 0, rate: store.state.currentRate!, maxDigits: 0, store: store)
        var decimal = Decimal(string: value.getString(10)) ?? Decimal(0)
        var amount: Decimal = 0.0
        NSDecimalMultiplyByPowerOf10(&amount, &decimal, Int16(-18), .up)
        let eth = NSDecimalNumber(decimal: amount)
        return placeholderAmount.tokenFormat.string(from: eth) ?? ""
    }

    static func localEthString(value: GethBigInt, store: Store) -> String {
        guard let rate = store.state.currentRate else { return "" }
        let placeholderAmount = Amount(amount: 0, rate: store.state.currentRate!, maxDigits: 0, store: store)
        var decimal = Decimal(string: value.getString(10)) ?? Decimal(0)
        var amount: Decimal = 0.0
        NSDecimalMultiplyByPowerOf10(&amount, &decimal, Int16(-18), .up)
        let eth = NSDecimalNumber(decimal: amount)
        return placeholderAmount.localFormat.string(for: eth.doubleValue*rate.rate) ?? ""
    }
}
