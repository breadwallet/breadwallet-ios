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
        if var url = NSURL(string: string) {

            if let scheme = url.scheme, let resourceSpecifier = url.resourceSpecifier, url.host == nil {
                url = NSURL(string: "\(scheme)://\(resourceSpecifier)")!

                if url.scheme == "bitcoin", let host = url.host {
                    toAddress = host

                    url.query?.components(separatedBy: "&").forEach {
                        let pair = $0.components(separatedBy: "=")
                        if pair.count == 2 {
                            let key = pair[0]
                            if let value = pair[1].replacingOccurrences(of: "+", with: " ").replacingPercentEscapes(using: .utf8) {
                                if key == "amount" {
                                    amount = amount(forValue: value)
                                }
                            }
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
}
