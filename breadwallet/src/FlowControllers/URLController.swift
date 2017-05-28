//
//  URLController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-05-26.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation

class URLController : Trackable {

    init(store: Store) {
        self.store = store
    }

    var xSource, xSuccess, xError, uri: String?

    func handleUrl(_ url: URL) -> Bool {
        saveEvent("send:handle_url", attributes: [
                "scheme" : url.scheme ?? C.null,
                "host" : url.host ?? C.null,
                "path" : url.path ])

        switch url.scheme ?? "" {
        case "bread":
            if let query = url.query {
                for component in query.components(separatedBy: "&") {
                    let pair = component.components(separatedBy: "+")
                    if pair.count < 2 { continue }
                    let key = pair[0]
                    var value = component.substring(from: component.index(key.endIndex, offsetBy: 2))
                    value = (value.replacingOccurrences(of: "+", with: " ") as NSString).removingPercentEncoding!
                    switch key {
                    case "x-source":
                        xSource = value
                    case "x-success":
                        xSuccess = value
                    case "x-error":
                        xError = value
                    case "uri":
                        uri = value
                    default:
                        print("Key not supported: \(key)")
                    }
                }
            }

            if url.host == "scanqr" || url.path == "/scanqr" {
                store.trigger(name: .scanQr)
            } else if url.host == "addresslist" || url.path == "/addresslist" {
                copyWalletAddresses()
            } else if let uri = isBitcoinUri(url: url, uri: uri) {
                return handleBitcoinUri(uri)
            } else if BRBitID.isBitIDURL(url) {
                handleBitId()
            }
            return true
        case "bitcoin":
            return handleBitcoinUri(url)
        default:
            return false
        }
    }

    private func isBitcoinUri(url: URL, uri: String?) -> URL? {
        guard let uri = uri else { return nil }
        guard let bitcoinUrl = URL(string: uri) else { return nil }
        if (url.host == "bitcoin-uri" || url.path == "/bitcoin-uri") && bitcoinUrl.scheme == "bitcoin" {
            return url
        } else {
            return nil
        }
    }

    private func copyAddress() {

    }

    private func copyWalletAddresses() {

    }

    private func handleBitcoinUri(_ uri: URL) -> Bool {
        if let request = PaymentRequest(string: uri.absoluteString) {
            store.trigger(name: .receivedPaymentRequest(request))
            return true
        } else {
            return false
        }
    }

    private func handleBitId() {

    }

    private let store: Store

}
