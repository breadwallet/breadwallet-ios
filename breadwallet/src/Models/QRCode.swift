//
//  QRCode.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2018-06-27.
//  Copyright © 2018-2019 Breadwinner AG. All rights reserved.
//

import Foundation
import BRCrypto

enum QRCode: Equatable {
    case paymentRequest(PaymentRequest)
    case privateKey(String)
    case deepLink(URL)
    case invalid
    
    init(content: String) {
        if (Key.createFromString(asPrivate: content) != nil) || Key.isProtected(asPrivate: content) {
            self = .privateKey(content)
        } else if let url = URL(string: content), url.isDeepLink {
            self = .deepLink(url)
        } else if let paymentRequest = QRCode.detectPaymentRequest(fromURI: content) {
            self = .paymentRequest(paymentRequest)
        } else {
            self = .invalid
        }
    }
    
    private static func detectPaymentRequest(fromURI uri: String) -> PaymentRequest? {
        return Store.state.currencies
            .sorted(by: { lhs, _ in
                return lhs.tokenType == .native //For generic QR code scanning, we should prefer native currencies
            }).compactMap {
                PaymentRequest(string: uri, currency: $0)
            }.first
    }
    
    static func == (lhs: QRCode, rhs: QRCode) -> Bool {
        switch (lhs, rhs) {
        case (.paymentRequest(let a), .paymentRequest(let b)):
            return a.toAddress == b.toAddress
        case (.privateKey(let a), .privateKey(let b)):
            return a == b
        case (.deepLink(let a), .deepLink(let b)):
            return a == b
        case (.invalid, .invalid):
            return true
        default:
            return false
        }
    }
}
