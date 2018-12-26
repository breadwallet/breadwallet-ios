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
            var errStr: String?
            if err == nil {
                do {
                    let parsedObject: Any? = try JSONSerialization.jsonObject(
                        with: data!, options: JSONSerialization.ReadingOptions.allowFragments)
                    if let top = parsedObject as? NSDictionary, let regular = top["fee_per_kb"] as? NSNumber, let economy = top["fee_per_kb_economy"] as? NSNumber {
                        regularFeePerKb = regular.uint64Value
                        economyFeePerKb = economy.uint64Value
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
            handler(Fees(regular: regularFeePerKb, economy: economyFeePerKb, timestamp: Date().timeIntervalSince1970), errStr)
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

    /// Fetches all token exchange rates in BTC from CoinMarketCap
    func tokenExchangeRates(_ handler: @escaping (RatesResult) -> Void) {
        let request = URLRequest(url: URL(string: "https://api.coinmarketcap.com/v1/ticker/?limit=1000&convert=BTC")!)
        dataTaskWithRequest(request, handler: { data, _, error in
            if error == nil, let data = data {
                do {
                    let codes = Store.state.currencies.map({ $0.code.lowercased() })
                    let tickers = try JSONDecoder().decode([Ticker].self, from: data)
                    let rates: [Rate] = tickers.compactMap({ ticker in
                        guard ticker.btcRate != nil, let rate = Double(ticker.btcRate!) else { return nil }
                        guard codes.contains(ticker.symbol.lowercased()) else { return nil }
                        return Rate(code: Currencies.btc.code,
                                    name: ticker.name,
                                    rate: rate,
                                    reciprocalCode: ticker.symbol.lowercased())
                    })
                    handler(.success(rates))
                } catch let e {
                    handler(.error(e.localizedDescription))
                }
            } else {
                handler(.error(error?.localizedDescription ?? "unknown error"))
            }
        }).resume()
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
        let path = currency.matches(Currencies.btc) ? "/q/addrs/utxo" : "/q/addrs/utxo?currency=bch"
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
