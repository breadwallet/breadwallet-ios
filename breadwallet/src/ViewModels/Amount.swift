//
//  Amount.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-01-15.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation

struct Amount {

    let amount: UInt64 //amount in satoshis
    var bits: String {
        guard let string = format.string(from: amount/100 as NSNumber) else { return "" }
        return string
    }

    var localCurrency: String {
        guard let string = localFormat.string(from: Double(amount)/100000000.0*830.0 as NSNumber) else { return "" }
        return string
    }

    private let format: NumberFormatter = {
        let format = NumberFormatter()
        format.isLenient = true
        format.numberStyle = .currency
        format.generatesDecimalNumbers = true
        format.negativeFormat = format.positiveFormat.replacingCharacters(in: format.positiveFormat.range(of: "#")!, with: "-#")
        format.currencyCode = "XBT"
        format.currencySymbol = "\(S.Symbols.bits)\(S.Symbols.narrowSpace)"
        format.maximumFractionDigits = 2
        format.minimumFractionDigits = 0
        format.maximum = C.maxMoney as NSNumber
        return format
    }()

    private let localFormat: NumberFormatter = {
        let format = NumberFormatter()
        format.isLenient = true
        format.numberStyle = .currency
        format.generatesDecimalNumbers = true
        format.negativeFormat = format.positiveFormat.replacingCharacters(in: format.positiveFormat.range(of: "#")!, with: "-#")
        return format
    }()
}
