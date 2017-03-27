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

    init?(string: String) {
        if var url = NSURL(string: string.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).replacingOccurrences(of: " ", with: "%20")) {
            if let scheme = url.scheme, let resourceSpecifier = url.resourceSpecifier, url.host == nil {
                url = NSURL(string: "\(scheme)://\(resourceSpecifier)")!

                if url.scheme == "bitcoin", let host = url.host {
                    toAddress = host
                    type = .local
                    guard let components = url.query?.components(separatedBy: "&") else { return }
                    for component in components {
                        let pair = component.components(separatedBy: "=")
                        if pair.count < 2 { continue }
                        let key = pair[0]
                        var value = component.substring(from: component.index(key.endIndex, offsetBy: 2))
                        value = (value.replacingOccurrences(of: "+", with: " ") as NSString).removingPercentEncoding!

                        switch key {
                        case "amount":
                            amount = amount(forValue: value)
                        case "label":
                            label = value
                        case "message":
                            message = value
                        default:
                            print("Key not found: \(key)")
                        }
                    }

                    return
                }
            } else if url.scheme == "http" || url.scheme == "https" {
                type = .remote
                remoteRequest = url
                return
            }
        }

        if string.utf8.count > 0 {
            toAddress = string
            type = .local
            return
        }

        return nil
    }

    init?(data: Data) {
        data.withUnsafeBytes({ (bytes: UnsafePointer<UInt8>) -> Void in
            let _ = BRPaymentProtocolRequestParse(bytes, data.count)
            //TODO - we now have a BRPaymentProtocolRequest struct to play with here
        })
        type = .local
    }

    func fetchRemoteRequest(completion: @escaping (PaymentRequest?) -> Void) {
        let request = NSMutableURLRequest(url: remoteRequest as! URL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 5.0)
        request.setValue("application/bitcoin-paymentrequest", forHTTPHeaderField: "Accept")


        URLSession.shared.dataTask(with: request as URLRequest) { data, response, error in
            guard error == nil else { return completion(nil) }
            guard let data = data else { return completion(nil) }
            guard let response = response else { return completion(nil) }

            if response.mimeType?.lowercased() == "application/bitcoin-paymentrequest" {
                completion(PaymentRequest(data: data))
            } else if response.mimeType?.lowercased() == "text/uri-list" {
                for line in (String(data: data, encoding: .utf8)?.components(separatedBy: "\n"))! {
                    if line.hasPrefix("#") { continue }
                    completion(PaymentRequest(string: line))
                    break
                }
            }
        }.resume()
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

    var toAddress: String?
    let type: PaymentRequestType
    var amount: UInt64?
    var label: String?
    var message: String?
    var remoteRequest: NSURL?
}
