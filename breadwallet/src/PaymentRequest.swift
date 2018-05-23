//
//  PaymentRequest.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-03-26.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation
import BRCore

enum PaymentRequestType {
    case local
    case remote
}

struct PaymentRequest {

    init?(string: String, currency: CurrencyDef) {
        self.currency = currency
        if var url = NSURL(string: string.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).replacingOccurrences(of: " ", with: "%20")) {
            if let scheme = url.scheme, let resourceSpecifier = url.resourceSpecifier, url.host == nil {
                url = NSURL(string: "\(scheme)://\(resourceSpecifier)")!

                if let scheme = url.scheme, let currencySchemes = currency.urlSchemes, currencySchemes.contains(scheme) {
                    let host = url.host
                    if let host = host, currency.matches(Currencies.bch) {
                        // BCH CashAddr includes the bitcoincash: prefix in the address format
                        // the payment request stores the address in legacy address
                        toAddress = "\(scheme):\(host)".bitcoinAddr
                        if toAddress == "" {
                            toAddress = host
                            warningMessage = S.Send.legacyAddressWarning
                        }
                    } else {
                        toAddress = host
                    }
                    guard let components = url.query?.components(separatedBy: "&") else { type = .local; return }
                    for component in components {
                        let pair = component.components(separatedBy: "=")
                        if pair.count < 2 { continue }
                        let key = pair[0]
                        var value = String(component[component.index(key.endIndex, offsetBy: 1)...])
                        value = (value.replacingOccurrences(of: "+", with: " ") as NSString).removingPercentEncoding!

                        switch key {
                        case "amount":
                            amount = Amount(tokenString: value, currency: currency, locale: Locale(identifier: "en_US"))
                        case "label", "memo":
                            label = value
                        case "message":
                            message = value
                        case "r":
                            r = URL(string: value)
                        default:
                            print("Key not found: \(key)")
                        }
                    }
                    //Payment request must have either an r value or an address
                    if r == nil {
                        if toAddress == nil {
                            return nil
                        }
                    }

                    type = r == nil ? .local : .remote
                    return
                }
            } else if url.scheme == "http" || url.scheme == "https" {
                type = .remote
                remoteRequest = url
                return
            }
        }
        
        // core internally uses bitcoin address format but PaymentRequest will only accept the currency-specific address format
        if currency.isValidAddress(string) {
            if currency.matches(Currencies.bch) {
                toAddress = string.bitcoinAddr
            } else {
                toAddress = string
            }
            type = .local
            return
        }
        
        return nil
    }

    init?(data: Data, currency: CurrencyDef) {
        self.currency = currency
        self.paymentProtocolRequest = PaymentProtocolRequest(data: data)
        type = .local
    }

    init?(json: String, currency: CurrencyDef) {
        self.currency = currency
        self.paymentProtocolRequest = PaymentProtocolRequest(json: json)
        type = .local
    }

    func fetchRemoteRequest(completion: @escaping (PaymentRequest?) -> Void) {
        let request: NSMutableURLRequest
        if let url = r {
            request = NSMutableURLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 5.0)
        } else {
            request = NSMutableURLRequest(url: remoteRequest! as URL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 5.0) //TODO - fix !
        }
        
        if self.currency.matches(Currencies.btc) {
            request.setValue("application/bitcoin-paymentrequest", forHTTPHeaderField: "Accept")
            //request.addValue("application/payment-request", forHTTPHeaderField: "Accept") // this breaks bitpay :(
        }
        else {
            request.setValue("application/payment-request", forHTTPHeaderField: "Accept")
        }

        URLSession.shared.dataTask(with: request as URLRequest) { data, response, error in
            guard error == nil else { return completion(nil) }
            guard let data = data else { return completion(nil) }
            guard let response = response else { return completion(nil) }

            if response.mimeType?.lowercased() == "application/bitcoin-paymentrequest" {
                completion(PaymentRequest(data: data, currency: Currencies.btc))
            }
            else if response.mimeType?.lowercased() == "application/payment-request" {
                // TODO: XXX validate hash from response header
                let req = PaymentRequest(json: String(data: data, encoding: .utf8) ?? "", currency: self.currency)
                // TODO: XXX populate the certified common name from the https response
                completion(req)
            }
            else if response.mimeType?.lowercased() == "text/uri-list" {
                for line in (String(data: data, encoding: .utf8)?.components(separatedBy: "\n"))! {
                    if line.hasPrefix("#") { continue }
                    completion(PaymentRequest(string: line, currency: self.currency))
                    break
                }
                completion(nil)
            } else {
                print("\"\(response.mimeType?.lowercased() ?? "")\"\n")
                print("\(String(data: data, encoding: .utf8) ?? "")\n")
                completion(nil)
            }
        }.resume()
    }

    static func requestString(withAddress address: String, forAmount amount: UInt256, currency: CurrencyDef) -> String {
        let amountString = amount.string(decimals: currency.commonUnit.decimals)
        guard let uri = currency.addressURI(address) else { return "" }
        return "\(uri)?amount=\(amountString)"
    }

    let currency: CurrencyDef
    var toAddress: String?
    var displayAddress: String? {
        if currency.matches(Currencies.bch) {
            return toAddress?.bCashAddr
        } else {
            return toAddress
        }
    }
    let type: PaymentRequestType
    var amount: Amount?
    var label: String?
    var message: String?
    var remoteRequest: NSURL?
    var paymentProtocolRequest: PaymentProtocolRequest?
    var r: URL?
    var warningMessage: String? //Displayed to the user before the send view fields are populated
}
