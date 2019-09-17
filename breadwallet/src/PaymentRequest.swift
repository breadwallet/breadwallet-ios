//
//  PaymentRequest.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-03-26.
//  Copyright © 2017-2019 Breadwinner AG. All rights reserved.
//

import Foundation
import BRCrypto

enum PaymentRequestType {
    case local
    case remote
}

extension PaymentProtocolRequest {
    var displayText: String? {
        if let name = commonName {
            return isSecure ? "\(S.Symbols.lock) \(name.sanitized)" : name.sanitized
        } else {
            return primaryTarget?.description
        }
    }
}

struct PaymentRequest {

    static let jsonHeader = "application/payment-request"
    static let bip70header = "application/bitcoin-paymentrequest"
    
    let currency: Currency
    var toAddress: Address?
    let type: PaymentRequestType
    var amount: Amount?
    var label: String?
    var message: String?
    var remoteRequest: URL?
    var paymentProtocolRequest: PaymentProtocolRequest?
    var r: URL?
    
    init?(string: String, currency: Currency) {
        self.currency = currency
        if let url = NSURL(string: string.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).replacingOccurrences(of: " ", with: "%20")) {
            if let scheme = url.scheme, let resourceSpecifier = url.resourceSpecifier, url.host == nil,
                let url = NSURL(string: "\(scheme)://\(resourceSpecifier)"),
                scheme == currency.urlScheme {
                if let host = url.host {
                    guard let address = Address.create(string: host, network: currency.network) else { return nil }
                    toAddress = address
                }
                
                //TODO: add support for ERC-681 token transfers, amount field, amount as scientific notation
                if let components = url.query?.components(separatedBy: "&") {
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
                }
                //Payment request must have either an r value or an address
                if r == nil {
                    guard toAddress != nil else { return nil }
                    type = .local
                } else {
                    type = .remote
                }
                return
            } else if url.scheme == "http" || url.scheme == "https" {
                type = .remote
                remoteRequest = url as URL
                return
            }
        }
        
        if let address = Address.create(string: string, network: currency.network) {
            toAddress = address
            type = .local
            return
        }
        
        return nil
    }

    init?(data: Data, currency: Currency) {
        guard let wallet = currency.wallet else { return nil }
        self.currency = currency
        self.paymentProtocolRequest = wallet.createPaymentProtocolRequest(forBip70: data)
        type = .local
    }

    init?(jsonData: Data, currency: Currency) {
        guard let wallet = currency.wallet else { return nil }
        self.currency = currency
        self.paymentProtocolRequest = wallet.createPaymentProtocolRequest(forBitPay: jsonData)
        type = .local
    }

    func fetchRemoteRequest(completion: @escaping (PaymentRequest?) -> Void) {
        let url = r ?? remoteRequest!
        let request = NSMutableURLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10.0)

        if self.currency.isBitcoin {
            request.setValue(PaymentRequest.bip70header, forHTTPHeaderField: "Accept")
            //TODO: use this header once json supports isSecure and commonName
            //request.setValue(PaymentRequest.jsonHeader, forHTTPHeaderField: "Accept")
        } else {
            request.setValue(PaymentRequest.jsonHeader, forHTTPHeaderField: "Accept")
        }

        URLSession.shared.dataTask(with: request as URLRequest) { data, response, error in
            guard error == nil else { return completion(nil) }
            guard let data = data else { return completion(nil) }
            guard let response = response else { return completion(nil) }

            if response.mimeType?.lowercased() == PaymentRequest.bip70header {
                guard let btc = Currencies.btc.instance else { return completion(nil) }
                completion(PaymentRequest(data: data, currency: btc))
            } else if response.mimeType?.lowercased() == PaymentRequest.jsonHeader {
                let req = PaymentRequest(jsonData: data, currency: self.currency)
                completion(req)
            } else if response.mimeType?.lowercased() == "text/uri-list" {
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

    static func requestString(withAddress address: String, forAmount amount: Amount) -> String {
        let amountString = amount.tokenUnformattedString(in: amount.currency.defaultUnit)
        guard let uri = amount.currency.addressURI(address) else { return "" }
        return "\(uri)?amount=\(amountString)"
    }
    
    static func postProtocolPayment(protocolRequest protoReq: PaymentProtocolRequest, transfer: Transfer, callback: @escaping (String) -> Void) {
        let payment = protoReq.createPayment(transfer: transfer)
        guard let url = protoReq.paymentURL else { return }
        let request = NSMutableURLRequest(url: URL(string: url)!, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 20.0)
        request.httpMethod = "POST"
        request.setValue("application/bitcoin-payment", forHTTPHeaderField: "Content-Type")
        request.addValue("application/bitcoin-paymentack", forHTTPHeaderField: "Accept")
        request.httpBody = payment?.encode()
        print("[PAY] Sending PaymentProtocolPayment to: \(url)")
        URLSession.shared.dataTask(with: request as URLRequest) { data, response, error in
            guard error == nil else { print("[PAY] error: \(error!)"); return }
            guard let data = data, response != nil else { print("[PAY] no data or response"); return }
            var memo: String?
            if let ack = PaymentProtocolPaymentACK.create(forBip70: data) {
                memo = ack.memo
            } else if let ack = PaymentProtocolPaymentACK.create(forBitPay: data) {
                memo = ack.memo
            }
            if let memo = memo {
                DispatchQueue.main.async {
                    callback(memo)
                }
            }
            }.resume()
    }
}
