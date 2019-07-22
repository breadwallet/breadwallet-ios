//
//  BRAPIClient+History.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2019-04-02.
//  Copyright © 2019 breadwallet LLC. All rights reserved.
//

import Foundation

enum PriceChangeResult {
    case success([String: PriceChange])
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

extension BRAPIClient {
    
    // Fetches 24hr price change history for each currency versus
    // the user's current display currency
    // -includes fiat and percent change info eg. +13% ($100)
    func fetchChange(currencies: [Currency], _ handler: @escaping (PriceChangeResult) -> Void) {
        
        // fsyms param (comma-separated ticker symbols) max length is 300 characters
        // requests are batched to ensure the length is not exceeded
        let chunkSize = 50
        let chunks = currencies.chunked(by: chunkSize)
        let currentCode = Store.state.defaultCurrencyCode
        
        var combinedResults: [String: PriceChange] = [:]
        var errorResult: PriceChangeResult?
        
        let group = DispatchGroup()
        for chunk in chunks {
            group.enter()
            let codes = chunk.map({ $0.code.uppercased() })
            guard let codeList = codes.joined(separator: ",").addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                assertionFailure()
                errorResult = .error("invalid token codes")
                return group.leave()
            }
            let request = URLRequest(url: URL(string: "https://min-api.cryptocompare.com/data/pricemultifull?fsyms=\(codeList)&tsyms=\(currentCode.uppercased())")!)
            dataTaskWithRequest(request, handler: { data, _, error in
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
                            let percentChange = prices[$0]?[currentCode]?["CHANGEPCT24HOUR"] as? Double else { return }
                        combinedResults[$0] = PriceChange(changePercentage24Hrs: percentChange, change24Hrs: change)
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
                handler(.success(combinedResults))
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
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .secondsSince1970
            do {
                let response = try decoder.decode(HistoryResponseContainer.self, from: data)
                callback(.success(reduceDataSize(array: response.Data, byFactor: period.reductionFactor)))
            } catch {
                callback(.unavailable)
            }
        }).resume()
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
