//
//  URLController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-05-26.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

class URLController : Trackable {

    init(store: Store, walletManager: WalletManager) {
        self.store = store
        self.walletManager = walletManager
    }

    private let store: Store
    private let walletManager: WalletManager
    private var xSource, xSuccess, xError, uri: String?

    func handleUrl(_ url: URL) -> Bool {
        saveEvent("send.handleURL", attributes: [
            "scheme" : url.scheme ?? C.null,
            "host" : url.host ?? C.null,
            "path" : url.path
        ])

        switch url.scheme ?? "" {
        case "bread":
            if let query = url.query {
                for component in query.components(separatedBy: "&") {
                    let pair = component.components(separatedBy: "+")
                    if pair.count < 2 { continue }
                    let key = pair[0]
                    var value = String(component[component.index(key.endIndex, offsetBy: 2)...])
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
                store.trigger(name: .copyWalletAddresses(xSuccess, xError))
            } else if url.path == "/address" {
                if let success = xSuccess {
                    copyAddress(callback: success)
                }
            } else if let uri = isBitcoinUri(url: url, uri: uri) {
                return handleBitcoinUri(uri)
            }
            return true
        case "bitcoin":
            return handleBitcoinUri(url)
        case "bitid":
            if BRBitID.isBitIDURL(url) {
                handleBitId(url)
            }
            return true
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

    private func copyAddress(callback: String) {
        if let url = URL(string: callback), let wallet = walletManager.wallet {
            let queryLength = url.query?.utf8.count ?? 0
            let callback = callback.appendingFormat("%@address=%@", queryLength > 0 ? "&" : "?", wallet.receiveAddress)
            if let callbackURL = URL(string: callback) {
                UIApplication.shared.openURL(callbackURL)
            }
        }
    }

    private func handleBitcoinUri(_ uri: URL) -> Bool {
        if let request = PaymentRequest(string: uri.absoluteString) {
            store.trigger(name: .receivedPaymentRequest(request))
            return true
        } else {
            return false
        }
    }

    private func handleBitId(_ url: URL) {
        let bitid = BRBitID(url: url, walletManager: walletManager)
        let message = String(format: S.BitID.authenticationRequest, bitid.siteName)
        let alert = UIAlertController(title: S.BitID.title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: S.BitID.deny, style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: S.BitID.approve, style: .default, handler: { _ in
            bitid.runCallback(store: self.store) { data, response, error in
                if let resp = response as? HTTPURLResponse, error == nil && resp.statusCode >= 200 && resp.statusCode < 300 {
                    let alert = UIAlertController(title: S.BitID.success, message: nil, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: S.Button.ok, style: .default, handler: nil))
                    self.present(alert: alert)
                } else {
                    let alert = UIAlertController(title: S.BitID.error, message: S.BitID.errorMessage, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: S.Button.ok, style: .default, handler: nil))
                    self.present(alert: alert)
                }
            }
        }))
        present(alert: alert)
    }

    private func present(alert: UIAlertController) {
        store.trigger(name: .showAlert(alert))
    }
}
