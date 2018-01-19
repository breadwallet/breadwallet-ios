//
//  NumberFormatter+Additions.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-05-21.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation

extension NumberFormatter {
    static func formattedString(amount: Satoshis, rate: Rate?, minimumFractionDigits: Int?, maxDigits: Int) -> String {
        let displayAmount = Amount(amount: amount.rawValue, rate: rate ?? Rate.empty, maxDigits: maxDigits)
        var formatter: NumberFormatter
        var output = ""
        if let rate = rate {
            formatter = NumberFormatter()
            if let minimumFractionDigits = minimumFractionDigits {
                formatter.minimumFractionDigits = minimumFractionDigits
            }
            formatter.locale = rate.locale
            formatter.numberStyle = .currency
            let value = (Double(amount.rawValue)/Double(C.satoshis))*rate.rate
            output = formatter.string(from: value as NSNumber) ?? "error"
        } else {
            formatter = displayAmount.btcFormat
            if let minimumFractionDigits = minimumFractionDigits {
                formatter.minimumFractionDigits = minimumFractionDigits
            }
            let bits = Bits(satoshis: amount)
            output = formatter.string(from: bits.rawValue as NSNumber) ?? "error"
        }
        return output
    }
}
