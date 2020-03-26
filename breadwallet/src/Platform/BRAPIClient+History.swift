//
//  BRAPIClient+History.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2019-04-02.
//  Copyright © 2019 breadwallet LLC. All rights reserved.
//

import Foundation

enum FiatPriceInfoResult {
    case success([String: FiatPriceInfo])
    case error(String)
}

//Data container for cryptocompare.com/data/histoday endpoint
struct HistoryResponseContainer: Codable {
    let Data: [PriceDataPoint]
}

//Data points used in the chart on the Account Screen
struct PriceDataPoint: Codable, Equatable {
    let time: Date
    let close: Double
}

enum PriceHistoryResult {
    case success([PriceDataPoint])
    case unavailable
}

struct FixerResult: Codable {
    var rates: [String: Double]
}

extension BRAPIClient {
 
    static func shouldUseUSDRate(currencyCodes: [String]) -> Bool {
        let code = Store.state.defaultCurrencyCode
        if C.fixerFiatCurrencies.contains(code.uppercased()) {
            return true
        }
        var cyrptoCodeFound = false
        currencyCodes.forEach {
            if C.fixerCryptoCurrencies.contains($0.uppercased()) {
                cyrptoCodeFound = true
            }
        }
        return cyrptoCodeFound
    }
    
    // Fetches price information relative to the user's default fiat currency for the given crypto currencies,
    // including the 24-hour price change, the current fiat price, and fiat percent change, e.g., +13% ($100)
    func fetchPriceInfo(currencies: [Currency], _ handler: @escaping (FiatPriceInfoResult) -> Void) {
        
        // fsyms param (comma-separated ticker symbols) max length is 300 characters
        // requests are batched to ensure the length is not exceeded
        let chunkSize = 50
        let chunks = currencies.chunked(by: chunkSize)
        
        let shouldUseUSDRate = BRAPIClient.shouldUseUSDRate(currencyCodes: currencies.map { $0.cryptoCompareCode })
        let currentCode = shouldUseUSDRate ? "USD" : Store.state.defaultCurrencyCode
        
        var combinedResults: [String: FiatPriceInfo] = [:]
        var errorResult: FiatPriceInfoResult?
        
        let queue = DispatchQueue.global(qos: .utility)
        let group = DispatchGroup()
        for chunk in chunks {
            group.enter()
            let codes = chunk.map { $0.cryptoCompareCode }
            guard let codeList = codes.joined(separator: ",").addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                assertionFailure()
                errorResult = .error("invalid token codes")
                return group.leave()
            }
            let request = URLRequest(url: URL(string: "https://min-api.cryptocompare.com/data/pricemultifull?fsyms=\(codeList)&tsyms=\(currentCode.uppercased())")!)
            dataTaskWithRequest(request, responseQueue: queue, handler: { data, _, error in
                guard error == nil, let data = data else {
                    errorResult = .error(error?.localizedDescription ?? "unknown error")
                    return group.leave()
                }
                do {
                    guard let data = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                        let prices = data["RAW"] as? [String: [String: [String: Any]]] else {
                        errorResult = .error("exchange rate API error")
                        return group.leave()
                    }
                    codes.forEach {
                        guard let change = prices[$0]?[currentCode]?["CHANGE24HOUR"] as? Double,
                            let percentChange = prices[$0]?[currentCode]?["CHANGEPCT24HOUR"] as? Double,
                            let price = prices[$0]?[currentCode]?["PRICE"] as? Double else { return }
                        combinedResults[$0] = FiatPriceInfo(changePercentage24Hrs: percentChange,
                                                          change24Hrs: change,
                                                          price: price)
                    }
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
                self.convertFor(info: combinedResults) { foo in
                    DispatchQueue.main.async {
                        handler(.success(foo))
                    }
                }
            }
        }
    }
    
    // Fetches historical prices for a given currency and history period in the user's
    // current display currency.
    //
    // The returned data points are uses to display the chart on the account screen
    func fetchHistory(forCode: String, period: HistoryPeriod, callback: @escaping (PriceHistoryResult) -> Void) {
        let request = URLRequest(url: period.urlForCode(code: forCode))
        dataTaskWithRequest(request, handler: { data, _, error in
            guard error == nil, let data = data else { callback(.unavailable); return }
            DispatchQueue.global(qos: .utility).async {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .secondsSince1970
                do {
                    let response = try decoder.decode(HistoryResponseContainer.self, from: data)
                    let reduced = reduceDataSize(array: response.Data, byFactor: period.reductionFactor)
                    self.convertFor(code: forCode, data: reduced) { history in
                        DispatchQueue.main.async {
                            callback(.success(history))
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        callback(.unavailable)
                    }
                }
            }
        }).resume()
    }

    func convertFor(code: String, data: [PriceDataPoint], callback: @escaping (([PriceDataPoint]) -> Void)) {
        guard BRAPIClient.shouldUseUSDRate(currencyCodes: [code]) else { return callback(data) }
        self.fetchFiatRate { rate in
            let result = data.map {
                //Convert from USD
                return PriceDataPoint(time: $0.time, close: $0.close * rate)
            }
            callback(result)
        }
        
    }
    
    func convertFor(info: [String: FiatPriceInfo], callback: @escaping ([String: FiatPriceInfo]) -> Void) {
        guard BRAPIClient.shouldUseUSDRate(currencyCodes: Array(info.keys)) else { return callback(info) }
        self.fetchFiatRate { rate in
            let prices = self.convert(info: info, withRate: rate)
            callback(prices)
        }
    }
    
    func fetchFiatRate(_ callback: @escaping (Double) -> Void) {
        KeyStore.getFixerApiToken { [weak self] token in
            guard let `self` = self else { return }
            guard let token = token else { return }
            let code = Store.state.defaultCurrencyCode
            let url = URL(string: "http://data.fixer.io/api/latest?access_key=\(token)&base=USD&symbols=\(code)")!
            self.saveEvent(Event.fixerFetch.name)
            URLSession.shared.dataTask(with: url, completionHandler: { data, _, error in
                guard let data = data else { print("error: \(error!)"); return }
                do {
                    let result = try JSONDecoder().decode(FixerResult.self, from: data)
                    if let rate = result.rates[code] {
                        callback(rate)
                    }
                } catch let e {
                    print("JSON decoding error: \(e)")
                }
            }).resume()
        }
    }
    
    //Converts from USD
    func convert(info: [String: FiatPriceInfo], withRate rate: Double) -> [String: FiatPriceInfo] {
        return info.mapValues {
            return FiatPriceInfo(changePercentage24Hrs: $0.changePercentage24Hrs,
                                 change24Hrs: $0.change24Hrs * rate,
                                 price: $0.price * rate)
        }
    }

}

//Reduces the size of an array by a factor.
// eg. a reduction factor of 6 would reduce an array of size
// 1095 to 1095/6=182
private func reduceDataSize<T: Equatable>(array: [T], byFactor: Int) -> [T] {
    guard byFactor > 0 else { return array }
    var newArray = array.enumerated().filter({ i, _ in
        i % byFactor == 0
    }).map { $0.1 }
    
    //If last item was removed, add it back. This makes
    //the current price more accurate
    if array.last != newArray.last {
        newArray.append(array.last!)
    }
    return newArray
}
