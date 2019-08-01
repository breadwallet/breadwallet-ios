//
//  URLController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-05-26.
//  Copyright © 2017-2019 Breadwinner AG. All rights reserved.
//

import UIKit

class URLController: Trackable, Subscriber {

    init(walletAuthenticator: WalletAuthenticator) {
        self.walletAuthenticator = walletAuthenticator
    }

    private var urlWaitingForUnlock: URL?
    private let walletAuthenticator: WalletAuthenticator
    private var xSource, xSuccess, xError, uri: String?
        
    func handleUrl(_ url: URL) -> Bool {
        guard !Store.state.isLoginRequired else {
            // defer url handling until wallet is unlocked
            urlWaitingForUnlock = url
            Store.lazySubscribe(self,
                                selector: { $0.isLoginRequired != $1.isLoginRequired },
                                callback: { state in
                                    DispatchQueue.main.async {
                                        if !state.isLoginRequired, let url = self.urlWaitingForUnlock {
                                            self.urlWaitingForUnlock = nil
                                            _ = self.handleUrl(url)
                                            Store.unsubscribe(self)
                                        }
                                    }
            })
            return false
        }
        
        saveEvent("send.handleURL", attributes: [
            "scheme": url.scheme ?? C.null,
            "host": url.host ?? C.null,
            "path": url.path
        ])

        guard let scheme = url.scheme else { return false }
        
        switch scheme {
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
                Store.trigger(name: .scanQr)
            } else if let uri = isBitcoinUri(url: url, uri: uri),
                let btc = Currencies.btc.instance {
                return handlePaymentRequestUri(uri, currency: btc)
            } else if url.host == "debug" {
                handleDebugLink(url)
            }
            return true
            
        case "https" where url.isDeepLink:
            guard url.pathComponents.count >= 3 else { return false }
            let target = url.pathComponents[2]
            
            switch target {
            case "scanqr":
                Store.trigger(name: .scanQr)
                
            case "link-wallet":
                if let params = url.queryParameters,
                    let pubKey = params["publicKey"],
                    let identifier = params["id"],
                    let service = params["service"] {
                    let returnToURL = URL(string: params["return-to"] ?? "")
                    print("[EME] PAIRING REQUEST | pubKey: \(pubKey) | identifier: \(identifier) | service: \(service)")
                    Store.trigger(name: .promptLinkWallet(WalletPairingRequest(publicKey: pubKey, 
                                                                               identifier: identifier, 
                                                                               service: service,
                                                                               returnToURL: returnToURL)))
                }
            case "platform":
                // grab the rest of the URL, e.g., /exchange/buy/coinify
                let path = url.pathComponents[3...].joined(separator: "/")
                let link = path.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)
                let platformUrl = String(format: "/link?to=%@", link ?? "")
                Store.trigger(name: .openPlatformUrl(platformUrl))

            case "debug":
                handleDebugLink(url)
                
            default:
                print("unknown deep link: \(target)")
            }
            
            return true
            
        case "bitid":
            if BRBitID.isBitIDURL(url) {
                return handleBitId(url)
            }
            
        default:
            guard let currency = Store.state.currencies.first(where: { $0.urlScheme == scheme }) else { return false }
            return handlePaymentRequestUri(url, currency: currency)
        }
        
        return false
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

    private func handlePaymentRequestUri(_ uri: URL, currency: Currency) -> Bool {
        if let request = PaymentRequest(string: uri.absoluteString, currency: currency) {
            Store.trigger(name: .receivedPaymentRequest(request))
            return true
        } else {
            return false
        }
    }

    private func handleBitId(_ url: URL) -> Bool {
        let bitid = BRBitID(url: url, walletAuthenticator: walletAuthenticator)
        let message = String(format: S.BitID.authenticationRequest, bitid.siteName)
        let alert = UIAlertController(title: S.BitID.title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: S.BitID.deny, style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: S.BitID.approve, style: .default, handler: { _ in
            bitid.runCallback { _, response, error in
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
        return true
    }

    /// Set debug overrides
    private func handleDebugLink(_ url: URL) {
        guard let params = url.queryParameters else { return }

        if let backendHost = params["api_server"] {
            UserDefaults.debugBackendHost = backendHost
            Backend.apiClient.host = backendHost
        }

        if let webBundleName = params["web_bundle"] {
            UserDefaults.debugWebBundleName = webBundleName
        }

        if let urlText = params["bundle_debug_url"], let platformDebugURL = URL(string: urlText) {
            UserDefaults.platformDebugURL = platformDebugURL
        }
    }

    private func present(alert: UIAlertController) {
        Store.trigger(name: .showAlert(alert))
    }
}

extension URL {
    public var isDeepLink: Bool {
        guard let domain = host?.split(separator: ".").suffix(2).joined(separator: "."), domain == "brd.com" else { return false }
        return path.hasPrefix("/x/")
    }
    
    public var queryParameters: [String: String]? {
        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: true), let queryItems = components.queryItems else {
            return nil
        }
        
        var parameters = [String: String]()
        for item in queryItems {
            parameters[item.name] = item.value
        }
        
        return parameters
    }
}
