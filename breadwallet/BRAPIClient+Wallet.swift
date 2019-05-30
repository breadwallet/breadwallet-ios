//
//  BRAPIClient+Wallet.swift
//  breadwallet
//
//  Created by Samuel Sutch on 4/2/17.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation

private let fallbackRatesURL = "https://bitpay.com/api/rates"

enum RatesResult {
    case success([Rate])
    case error(String)
}

extension BRAPIClient {

    func me(handler: @escaping (_ success: Bool, _ response: Data?, _ error: Error?) -> Void) {
        let req = URLRequest(url: url("/me"))
        let task = dataTaskWithRequest(req, authenticated: true, handler: { data, response, err in
            if let data = data {
                print("me: \(String(describing: String(data: data, encoding: .utf8)))")
            }
            let success = response?.statusCode == 200
            handler(success, data, err)
        })
        task.resume()
    }

    func feePerKb(code: String, _ handler: @escaping (_ fees: Fees, _ error: String?) -> Void) {
        let param = code == Currencies.bch.code ? "?currency=bch" : ""
        let req = URLRequest(url: url("/fee-per-kb\(param)"))
        let task = self.dataTaskWithRequest(req) { (data, _, err) -> Void in
            var regularFeePerKb: uint_fast64_t = 0
            var economyFeePerKb: uint_fast64_t = 0
            var priorityFeePerKb: uint_fast64_t = 0
            var errStr: String?
            if err == nil {
                do {
                    let parsedObject: Any? = try JSONSerialization.jsonObject(
                        with: data!, options: JSONSerialization.ReadingOptions.allowFragments)
                    if let top = parsedObject as? NSDictionary,
                        let regular = top["fee_per_kb"] as? NSNumber,
                        let economy = top["fee_per_kb_economy"] as? NSNumber,
                        let priority = top["fee_per_kb_priority"] as? NSNumber {
                        regularFeePerKb = regular.uint64Value
                        economyFeePerKb = economy.uint64Value
                        priorityFeePerKb = priority.uint64Value
                    }
                } catch let e {
                    self.log("fee-per-kb: error parsing json \(e)")
                }
                if regularFeePerKb == 0 || economyFeePerKb == 0 {
                    errStr = "invalid json"
                }
            } else {
                self.log("fee-per-kb network error: \(String(describing: err))")
                errStr = "bad network connection"
            }
            handler(Fees(regular: regularFeePerKb, economy: economyFeePerKb, priority: priorityFeePerKb, timestamp: Date().timeIntervalSince1970), errStr)
        }
        task.resume()
    }
    
    /// Fetches Bitcoin exchange rates in all available fiat currencies
    func exchangeRates(currencyCode code: String, isFallback: Bool = false, _ handler: @escaping (RatesResult) -> Void) {
        let param = "?currency=\(code.lowercased())"
        let request = isFallback ? URLRequest(url: URL(string: fallbackRatesURL)!) : URLRequest(url: url("/rates\(param)"))
        let task = dataTaskWithRequest(request) { (data, _, error) in
            if error == nil, let data = data,
                let parsedData = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) {
                if isFallback {
                    guard let array = parsedData as? [Any] else {
                        return handler(.error("/rates didn't return an array"))
                    }
                    handler(.success(array.compactMap { Rate(data: $0, reciprocalCode: code) }))
                } else {
                    guard let dict = parsedData as? [String: Any],
                        let array = dict["body"] as? [Any] else {
                            return self.exchangeRates(currencyCode: code, isFallback: true, handler)
                    }
                    handler(.success(array.compactMap { Rate(data: $0, reciprocalCode: code) }))
                }
            } else {
                if isFallback {
                    handler(.error("Error fetching from fallback url"))
                } else {
                    self.exchangeRates(currencyCode: code, isFallback: true, handler)
                }
            }
        }
        task.resume()
    }

    /// Fetches BTC exchange rates of given currencies from CryptoCompare API
    func tokenExchangeRates(tokens: [Currency], _ handler: @escaping (RatesResult) -> Void) {
        // fsyms param (comma-separated ticker symbols) max length is 300 characters
        // requests are batched to ensure the length is not exceeded
        let chunkSize = 50
        let chunks = tokens.chunked(by: chunkSize)

        var combinedRates: [Rate] = []
        var errorResult: RatesResult?

        let group = DispatchGroup()
        for tokenChunk in chunks {
            group.enter()
            let codes = tokenChunk.map({ $0.code.uppercased() })
            guard let codeList = codes.joined(separator: ",").addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                assertionFailure()
                errorResult = .error("invalid token codes")
                return group.leave()
            }
            let request = URLRequest(url: URL(string: "https://min-api.cryptocompare.com/data/pricemulti?fsyms=\(codeList)&tsyms=BTC")!)
            dataTaskWithRequest(request, handler: { data, _, error in
                guard error == nil, let data = data else {
                    errorResult = .error(error?.localizedDescription ?? "unknown error")
                    return group.leave()
                }
                do {
                    guard let prices = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                        errorResult = .error("exchange rate API error")
                        return group.leave()
                    }
                    let rates: [Rate] = tokenChunk.compactMap({ currency in
                        guard let rateContainer = prices[currency.code.uppercased()] as? [String: Double],
                            let rate = rateContainer[Currencies.btc.code.uppercased()] else { return nil }
                        return Rate(code: Currencies.btc.code,
                                    name: currency.name,
                                    rate: rate,
                                    reciprocalCode: currency.code.lowercased())
                    })
                    combinedRates.append(contentsOf: rates)
                    group.leave()
                } catch let e {
                    errorResult = .error(e.localizedDescription)
                    group.leave()
                }
            }).resume()
        }

        group.notify(queue: .main) {
            if let errorResult = errorResult {
                handler(errorResult)
            } else {
                handler(.success(combinedRates))
            }
        }
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
            ] as [String: Any]
        do {
            let dat = try JSONSerialization.data(withJSONObject: reqJson, options: .prettyPrinted)
            req.httpBody = dat
        } catch let e {
            log("JSON Serialization error \(e)")
            return
        }
        dataTaskWithRequest(req as URLRequest, authenticated: true, retryCount: 0) { (dat, resp, _) in
            print("[PUSH] registered device token: \(reqJson)")
            let datString = String(data: dat ?? Data(), encoding: .utf8)
            self.log("save push token resp: \(resp?.statusCode ?? 0) data: \(String(describing: datString))")
        }.resume()
    }

    func deletePushNotificationToken(_ token: Data) {
        var req = URLRequest(url: url("/me/push-devices/apns/\(token.hexString)"))
        req.httpMethod = "DELETE"
        dataTaskWithRequest(req as URLRequest, authenticated: true, retryCount: 0) { (_, resp, _) in
            self.log("delete push token resp: \(String(describing: resp))")
            if let statusCode = resp?.statusCode {
                if statusCode >= 200 && statusCode < 300 {
                    UserDefaults.pushToken = nil
                    self.log("deleted old token")
                }
            }
        }.resume()
    }

    func fetchUTXOS(address: String, currency: Currency, completion: @escaping ([[String: Any]]?) -> Void) {
        //TODO:CRYPTO currency-type check
        let path = currency.isBitcoin ? "/q/addrs/utxo" : "/q/addrs/utxo?currency=bch"
        var req = URLRequest(url: url(path))
        req.httpMethod = "POST"
        req.httpBody = "addrs=\(address)".data(using: .utf8)
        dataTaskWithRequest(req, handler: { data, _, error in
            guard error == nil else { completion(nil); return }
            guard let data = data,
                let jsonData = try? JSONSerialization.jsonObject(with: data, options: []),
                let json = jsonData as? [[String: Any]] else { completion(nil); return }
                completion(json)
        }).resume()
    }
}

struct BTCRateResponse: Codable {
    let body: [BTCRate]
    
    struct BTCRate: Codable {
        let code: String
        let name: String
        let rate: Double
    }
}

struct Ticker: Codable {
    let symbol: String
    let name: String
    let usdRate: String?
    let btcRate: String?
    
    enum CodingKeys: String, CodingKey {
        case symbol
        case name
        case usdRate = "price_usd"
        case btcRate = "price_btc"
    }
}

private func pushNotificationEnvironment() -> String {
    return E.isDebug ? "d" : "p" //development or production
}
