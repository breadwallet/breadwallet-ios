//
//  BRAPIClient+Wallet.swift
//  breadwallet
//
//  Created by Samuel Sutch on 4/2/17.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation

private let fallbackRatesURL = "https://bitpay.com/api/rates"

extension BRAPIClient {
    func feePerKb(_ handler: @escaping (_ fees: Fees, _ error: String?) -> Void) {
        let req = URLRequest(url: url("/fee-per-kb"))
        let task = self.dataTaskWithRequest(req) { (data, response, err) -> Void in
            var regularFeePerKb: uint_fast64_t = 0
            var economyFeePerKb: uint_fast64_t = 0
            var errStr: String? = nil
            if err == nil {
                do {
                    let parsedObject: Any? = try JSONSerialization.jsonObject(
                        with: data!, options: JSONSerialization.ReadingOptions.allowFragments)
                    if let top = parsedObject as? NSDictionary, let regular = top["fee_per_kb"] as? NSNumber, let economy = top["fee_per_kb_economy"] as? NSNumber {
                        regularFeePerKb = regular.uint64Value
                        economyFeePerKb = economy.uint64Value
                    }
                } catch (let e) {
                    self.log("fee-per-kb: error parsing json \(e)")
                }
                if regularFeePerKb == 0 || economyFeePerKb == 0 {
                    errStr = "invalid json"
                }
            } else {
                self.log("fee-per-kb network error: \(String(describing: err))")
                errStr = "bad network connection"
            }
            handler(Fees(regular: regularFeePerKb, economy: economyFeePerKb), errStr)
        }
        task.resume()
    }
    
    func exchangeRates(isFallback: Bool = false, _ handler: @escaping (_ rates: [Rate], _ error: String?) -> Void) {
        let request = isFallback ? URLRequest(url: URL(string: fallbackRatesURL)!) : URLRequest(url: url("/rates"))
        let task = dataTaskWithRequest(request) { (data, response, error) in
            if error == nil, let data = data,
                let parsedData = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) {
                if isFallback {
                    guard let array = parsedData as? [Any] else {
                        return handler([], "/rates didn't return an array")
                    }
                    handler(array.flatMap { Rate(data: $0) }, nil)
                } else {
                    guard let dict = parsedData as? [String: Any],
                        let array = dict["body"] as? [Any] else {
                            return self.exchangeRates(isFallback: true, handler)
                    }
                    handler(array.flatMap { Rate(data: $0) }, nil)
                }
            } else {
                if isFallback {
                    handler([], "Error fetching from fallback url")
                } else {
                    self.exchangeRates(isFallback: true, handler)
                }
            }
        }
        task.resume()
    }
    
    func savePushNotificationToken(_ token: Data) {
        var req = URLRequest(url: url("/me/push-devices"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let reqJson = [
            "token": token.hexString,
            "service": "apns",
            "data": [   "e": pushNotificationEnvironment(),
                        "b": Bundle.main.bundleIdentifier!]
            ] as [String : Any]
        do {
            let dat = try JSONSerialization.data(withJSONObject: reqJson, options: .prettyPrinted)
            req.httpBody = dat
        } catch (let e) {
            log("JSON Serialization error \(e)")
            return
        }
        dataTaskWithRequest(req as URLRequest, authenticated: true, retryCount: 0) { (dat, resp, er) in
            let dat2 = String(data: dat ?? Data(), encoding: .utf8)
            self.log("save push token resp: \(String(describing: resp)) data: \(String(describing: dat2))")
        }.resume()
    }

    func deletePushNotificationToken(_ token: Data) {
        var req = URLRequest(url: url("/me/push-devices/apns/\(token.hexString)"))
        req.httpMethod = "DELETE"
        dataTaskWithRequest(req as URLRequest, authenticated: true, retryCount: 0) { (dat, resp, er) in
            self.log("delete push token resp: \(String(describing: resp))")
            if let statusCode = resp?.statusCode {
                if statusCode >= 200 && statusCode < 300 {
                    UserDefaults.pushToken = nil
                    self.log("deleted old token")
                }
            }
        }.resume()
    }

    func publishBCashTransaction(_ txData: Data, callback: @escaping (String?) -> Void) {
        var req = URLRequest(url: url("/bch/publish-transaction"))
        req.httpMethod = "POST"
        req.setValue("application/bcashdata", forHTTPHeaderField: "Content-Type")
        req.httpBody = txData
        dataTaskWithRequest(req as URLRequest, authenticated: true, retryCount: 0) { (dat, resp, er) in
            if let statusCode = resp?.statusCode {
                if statusCode >= 200 && statusCode < 300 {
                    callback(nil)
                } else if let data = dat, let errorString = NSString(data: data, encoding: String.Encoding.utf8.rawValue) {
                    callback(errorString as String)
                } else {
                    callback("\(statusCode)")
                }
            }
        }.resume()
    }
}

private func pushNotificationEnvironment() -> String {
    return E.isDebug ? "d" : "p" //development or production
}
