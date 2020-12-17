//
//  QRCode.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2018-06-27.
//  Copyright © 2018-2019 Breadwinner AG. All rights reserved.
//

import Foundation
import WalletKit

enum QRCode: Equatable {
    case paymentRequest(PaymentRequest)
    case privateKey(String)
    case gift(String, TxViewModel?)
    case deepLink(URL)
    case invalid
    
    init(content: String) {
        if let key = QRCode.extractPrivKeyFromGift(url: URL(string: content)!) {
            self = .gift(key, nil)
        } else if (Key.createFromString(asPrivate: content) != nil) || Key.isProtected(asPrivate: content) {
            self = .privateKey(content)
        } else if let url = URL(string: content), url.isDeepLink {
            self = .deepLink(url)
        } else if let paymentRequest = QRCode.detectPaymentRequest(fromURI: content) {
            self = .paymentRequest(paymentRequest)
        } else {
            self = .invalid
        }
    }
    
    //TxViewModel is needed for marking as reclaimed
    init?(url: URL, viewModel: TxViewModel?) {
        guard let key = QRCode.extractPrivKeyFromGift(url: url) else { return nil }
        self = .gift(key, viewModel)
    }
    
    private static func detectPaymentRequest(fromURI uri: String) -> PaymentRequest? {
        return Store.state.currencies
            .sorted(by: { lhs, _ in
                return lhs.tokenType == .native //For generic QR code scanning, we should prefer native currencies
            }).compactMap {
                PaymentRequest(string: uri, currency: $0)
            }.first
    }
    
    private static func extractPrivKeyFromGift(url: URL) -> String? {
        guard let privKeyComponent = Data(base64Encoded: url.lastPathComponent.paddedString) else { return nil }
        guard let decodedString = String(data: privKeyComponent, encoding: .utf8) else { return nil }
        guard Key.createFromString(asPrivate: decodedString) != nil else { return nil }
        return decodedString
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
        case (.gift, .gift):
            return true
        default:
            return false
        }
    }
}

private extension String {
    var paddedString: String {
        let paddedLength = utf8.count + (utf8.count % 4)
        return padding(toLength: paddedLength, withPad: "=", startingAt: 0)
    }
}
