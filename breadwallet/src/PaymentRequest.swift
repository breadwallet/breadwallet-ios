//
//  PaymentRequest.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-03-26.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation

struct PaymentRequest {

    init?(string: String) {
        if var url = NSURL(string: string.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).replacingOccurrences(of: " ", with: "%20")) {
            if let scheme = url.scheme, let resourceSpecifier = url.resourceSpecifier, url.host == nil {
                url = NSURL(string: "\(scheme)://\(resourceSpecifier)")!

                if url.scheme == "bitcoin", let host = url.host {
                    toAddress = host

                    guard let components = url.query?.components(separatedBy: "&") else { return }
                    for component in components {
                        let pair = component.components(separatedBy: "=")
                        if pair.count < 2 { continue }
                        let key = pair[0]
                        var value = component.substring(from: component.index(key.endIndex, offsetBy: 2))
                        value = (value.replacingOccurrences(of: "+", with: " ") as NSString).removingPercentEncoding!

                        switch key {
                        case "amount":
                            amount = amount(forValue: value)
                        case "label":
                            label = value
                        case "message":
                            message = value
                        default:
                            print("Key not found: \(key)")
                        }
                    }
                    return
                }
            }
        }

        if string.utf8.count > 0 {
            toAddress = string
            return
        }

        return nil
    }

    private func amount(forValue: String) -> UInt64? {
        var decimal: Decimal = 0.0
        var amount: Decimal = 0.0

        if Scanner(string: forValue).scanDecimal(&decimal) {
            NSDecimalMultiplyByPowerOf10(&amount, &decimal, 8, .up)
            return NSDecimalNumber(decimal: amount).uint64Value
        } else {
            return nil
        }
    }

    let toAddress: String
    var amount: UInt64?
    var label: String?
    var message: String?
}
