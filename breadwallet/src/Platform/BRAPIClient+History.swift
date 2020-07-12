//
//  BRAPIClient+History.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2019-04-02.
//  Copyright © 2019 breadwallet LLC. All rights reserved.
//

import Foundation
import CoinGecko

let gecko = ApiClient()

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
        let chunkSize = 50
        let chunks = currencies.chunked(by: chunkSize)
        var combinedResults: [String: FiatPriceInfo] = [:]
        let group = DispatchGroup()
        for chunk in chunks {
            group.enter()
            let coinGeckoIds = chunk.compactMap { $0.coinGeckoId }
            let vs = Store.state.defaultCurrencyCode.lowercased()
            let resource = Resources.simplePrice(ids: coinGeckoIds, vsCurrency: vs, options: [.change]) { (result: Result<PriceList, CoinGeckoError>) in
                guard case .success(let data) = result else { return group.leave() }
                coinGeckoIds.forEach { id in
                    guard let simplePrice = data.first(where: { $0.id == id }) else { return }
                    guard let change = simplePrice.change24hr else { return }
                    combinedResults[id] = FiatPriceInfo(changePercentage24Hrs: change,
                                                        change24Hrs: change*simplePrice.price,
                                                        price: simplePrice.price)
                }
                group.leave()
            }
            gecko.load(resource)
        }
        
        group.notify(queue: .main) {
            assert(Thread.isMainThread)
            handler(.success(combinedResults))
        }
    }
    
    // Fetches historical prices for a given currency and history period in the user's
    // current display currency.
    //
    // The returned data points are uses to display the chart on the account screen
    func fetchHistory(forCode: String, period: HistoryPeriod, callback: @escaping (PriceHistoryResult) -> Void) {
        let chart = Resources.marketChart(currencyId: "bitcoin", vs: "cad", days: period.days) { (result: Result<MarketChart, CoinGeckoError>) in
            guard case .success(let data) = result else { return }
            let points: [PriceDataPoint] = data.dataPoints.map {
                return PriceDataPoint(time: Date(timeIntervalSince1970: Double($0.timestamp)/1000.0), close: $0.price)
            }
            callback(.success(points))
        }
        gecko.load(chart)
    }
    
    func setHardcodedRates() {
        setHardcoded(rate: 100, baseCurrencyCode: "EUR", forCryptoCurrencyCode: "AVM")
        setHardcoded(rate: 1, baseCurrencyCode: "EUR", forCryptoCurrencyCode: "EUR.AVM")
    }
    
    func setHardcoded(rate: Double, baseCurrencyCode base: String, forCryptoCurrencyCode cryptoCode: String) {
        guard let currency = Store.state.currencies.first(where: { $0.code == cryptoCode }) else { return }
        let currentFiatCode = Store.state.defaultCurrencyCode
        
        //If default currency is the currency of the base rate, we don't need to convert
        guard currentFiatCode != base else {
            let rate = Rate(code: currentFiatCode, name: currency.name, rate: rate, reciprocalCode: currency.code)
            Store.perform(action: WalletChange(currency).setExchangeRate(rate))
            return
        }
        
        convert(from: base, to: currentFiatCode) { exchangeRate in
            DispatchQueue.main.async {
                let rate = Rate(code: currentFiatCode, name: currency.name, rate: rate*exchangeRate, reciprocalCode: currency.code)
                Store.perform(action: WalletChange(currency).setExchangeRate(rate))
            }
        }
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
    
    func convert(from: String, to: String, callback: @escaping (Double) -> Void) {
        KeyStore.getFixerApiToken { token in
            guard let token = token else { return }
            let url = URL(string: "http://data.fixer.io/api/latest?access_key=\(token)&base=\(from)&symbols=\(to)")!
            URLSession.shared.dataTask(with: url, completionHandler: { data, _, error in
                guard let data = data else { print("error: \(error!)"); return }
                do {
                    let result = try JSONDecoder().decode(FixerResult.self, from: data)
                    if let rate = result.rates[to] {
                        callback(rate)
                    } else {
                        print("Fixer result not found: \(result)")
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
