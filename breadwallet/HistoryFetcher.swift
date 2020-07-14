// 
//  HistoryFetcher.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2020-07-14.
//  Copyright © 2020 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import Foundation
import CoinGecko

enum PriceHistoryResult {
    case success([PriceDataPoint])
    case unavailable
}

//Data points used in the chart on the Account Screen
struct PriceDataPoint: Codable, Equatable {
    let time: Date
    let close: Double
}

class HistoryFetcher {
    
    private let client = CoinGeckoClient()
    
    // Fetches historical prices for a given currency and history period in the user's
    // current display currency.
    //
    // The returned data points are uses to display the chart on the account screen
    func fetchHistory(forCode code: String, period: HistoryPeriod, callback: @escaping (PriceHistoryResult) -> Void) {
        let chart = Resources.marketChart(currencyId: code, vs: UserDefaults.defaultCurrencyCode, days: period.days) { (result: Result<MarketChart, CoinGeckoError>) in
            guard case .success(let data) = result else { return }
            let points: [PriceDataPoint] = data.dataPoints.map {
                return PriceDataPoint(time: Date(timeIntervalSince1970: Double($0.timestamp)/1000.0), close: $0.price)
            }
            callback(.success(self.reduceDataSize(array: points, byFactor: period.reductionFactor)))
        }
        client.load(chart)
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
    
}
