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

private func parseString(_ string: String) -> NSURL? {
    let string = string.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: " ", with: "%20")
    guard let url = NSURL(string: string) else { return nil }
    return url
}

private func formatUrl(_ url: NSURL, forCurrency currency: Currency) -> NSURL? {
    //If the url has a host, then it's a remote request
    guard url.host == nil else { return nil }
    
    //make sure it's the right url Scheme
    guard url.scheme == currency.urlScheme else { return nil }
    
    //convert url to a format that can be parsed by NSURL
    //eg. bitcoin:12A1MyfXbW6RhdRAZEqofac5jCQQjwEPBu -> bitcoin://12A1MyfXbW6RhdRAZEqofac5jCQQjwEPBu
    guard let scheme = url.scheme, let resourceSpecifier = url.resourceSpecifier else { return nil }
    return NSURL(string: "\(scheme)://\(resourceSpecifier)")
}

struct PaymentRequest {

    // MARK: HTTP Headers
    static let jsonHeader = "application/payment-request"
    static let bip70header = "application/bitcoin-paymentrequest"
    static let bitPayPartnerKey = "BP_PARTNER"
    static let bitPayPartnerValue = "brd"
    static let bitPayPartnerVersionKey = "BP_PARTNER_VERSION"
    
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
        
        //Case: Incoming string is just a plain address
        if let address = Address.create(string: string, network: currency.network) {
            toAddress = address
            type = .local
            return
        }
        
        //Case: Incoming string is a url
        //By this stage, we know it's not an address, so if it's also
        //not a url, it's unparsable
        guard let rawUrl = parseString(string) else { return nil }
        
        //Case: Url is a remote request if the scheme is http or https
        guard rawUrl.scheme != "http" && rawUrl.scheme != "https" else {
            type = .remote
            remoteRequest = rawUrl as URL
            return
        }
        
        //Case: Url has a crypto scheme
        //eg. bitcoin:xxxxx or ethereum:xxxx
        guard let url = formatUrl(rawUrl, forCurrency: currency) else { return nil }
        
        //The toAddress is always the host except for EIP-681 (erc20 transfer) uris
        //where the toAddress is in the address param
        if let host = url.host, !(url.path?.contains("transfer") == true) {
            guard let address = Address.create(string: host, network: currency.network) else { return nil }
            toAddress = address
        }
        
        // Parse query params
        if let queryParams = URLComponents(string: url.description)?.queryItems {
            for param in queryParams {
                guard let value = param.value else { break }
                switch param.name {
                case "amount":
                    amount = Amount(tokenString: value, currency: currency, locale: Locale(identifier: "en_US"))
                case "label", "memo":
                    label = value
                case "message":
                    message = value
                case "r":
                    r = URL(string: value)
                case "address":
                    //ERC-681 - host should be the token address
                    if url.host?.lowercased() == currency.tokenAddress?.lowercased() {
                        toAddress = Address.create(string: value, network: currency.network)
                    } else {
                        return nil
                    }
                case "tokenaddress":
                    if value.lowercased() != currency.tokenAddress?.lowercased() {
                        return nil
                    }
                default:
                    print("Unknown Key found: \(param.name)")
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
        addBitpayPartnerHeaders(request: request)
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
        
        //Create URI for address
        let amountString = amount.tokenUnformattedString(in: amount.currency.defaultUnit)
        guard let uriString = amount.currency.addressURI(address) else { return "" }
        guard let uri = URL(string: uriString) else { return "" }
        
        //Append amount query item
        guard var components = URLComponents(url: uri, resolvingAgainstBaseURL: false) else { return "" }
        let amountItem = URLQueryItem(name: "amount", value: amountString)
        if components.queryItems != nil {
            components.queryItems?.append(amountItem)
        } else {
            components.queryItems = [amountItem]
        }
        
        return components.url?.absoluteString ?? ""
    }
    
    static func postProtocolPayment(protocolRequest protoReq: PaymentProtocolRequest, transfer: Transfer, callback: @escaping (String) -> Void) {
        let payment = protoReq.createPayment(transfer: transfer)
        guard let url = protoReq.paymentURL else { return }
        let request = NSMutableURLRequest(url: URL(string: url)!, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 20.0)
        request.httpMethod = "POST"
        request.setValue("application/bitcoin-payment", forHTTPHeaderField: "Content-Type")
        request.addValue("application/bitcoin-paymentack", forHTTPHeaderField: "Accept")
        addBitpayPartnerHeaders(request: request)
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

private func addBitpayPartnerHeaders(request: NSMutableURLRequest) {
    // ["BP_PARTNER": "brd", "BP_PARTNER_VERSION": "4.0"]
    request.setValue(PaymentRequest.bitPayPartnerValue, forHTTPHeaderField: PaymentRequest.bitPayPartnerKey)
    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
    request.setValue(version, forHTTPHeaderField: PaymentRequest.bitPayPartnerVersionKey)
}
