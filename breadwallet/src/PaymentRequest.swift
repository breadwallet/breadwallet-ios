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
        if let url = NSURL(string: string) {
            if url.scheme == "bitcoin" {
                if let host = url.resourceSpecifier {
                    toAddress = host
                } else {
                    return nil
                }
            } else {
                return nil
            }
        } else if string.utf8.count > 0 {
            toAddress = string
        } else {
            return nil
        }
    }

    let toAddress: String
    var amount: UInt64?
}
