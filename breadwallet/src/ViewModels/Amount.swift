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
    let rate: Double

    var bitsAmount: Double {
        return Double(amount)/100.0
    }

    var localAmount: Double {
        return Double(amount)/100000000.0*rate
    }

    var bits: String {
        let number = NSNumber(value: Double(amount)/100.0)
        guard let string = Amount.btcFormat.string(from: number) else { return "" }
        return string
    }

    var localCurrency: String {
        guard let string = Amount.localFormat.string(from: Double(amount)/100000000.0*rate as NSNumber) else { return "" }
        return string
    }

    func string(forLocal local: Locale) -> String {
        let format = NumberFormatter()
        format.locale = local
        format.isLenient = true
        format.numberStyle = .currency
        format.generatesDecimalNumbers = true
        format.negativeFormat = format.positiveFormat.replacingCharacters(in: format.positiveFormat.range(of: "#")!, with: "-#")
        guard let string = format.string(from: Double(amount)/100000000.0*rate as NSNumber) else { return "" }
        return string
    }

    func string(forCurrency: Currency) -> String {
        switch forCurrency {
        case .bitcoin:
            return bits
        case .local:
            return localCurrency
        }
    }

    //MARK: - Private
    static let btcFormat: NumberFormatter = {
        let format = NumberFormatter()
        format.isLenient = true
        format.numberStyle = .currency
        format.generatesDecimalNumbers = true
        format.negativeFormat = format.positiveFormat.replacingCharacters(in: format.positiveFormat.range(of: "#")!, with: "-#")
        format.currencyCode = "XBT"
        format.currencySymbol = "\(S.Symbols.bits)\(S.Symbols.narrowSpace)"
        format.maximumFractionDigits = 2
        format.minimumFractionDigits = 0 // iOS 8 bug, minimumFractionDigits now has to be set after currencySymbol
        format.maximum = C.maxMoney as NSNumber
        return format
    }()

    static let localFormat: NumberFormatter = {
        let format = NumberFormatter()
        format.isLenient = true
        format.numberStyle = .currency
        format.generatesDecimalNumbers = true
        format.negativeFormat = format.positiveFormat.replacingCharacters(in: format.positiveFormat.range(of: "#")!, with: "-#")
        return format
    }()
}
