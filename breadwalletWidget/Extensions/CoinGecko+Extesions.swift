// 
//  File.swift
//  breadwallet
//
//  Created by stringcode on 17/02/2021.
//  Copyright © 2021 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import Foundation
import CoinGecko

extension Resources {
        
    static func  chart<MarketChart>(base: String, quote: String, interval: Interval, callback: @escaping Callback<MarketChart>) -> Resource<MarketChart> {
        
        var params = [URLQueryItem(name: "vs_currency", value: quote),
                      URLQueryItem(name: "days", value: interval.queryVal())]
        
        if interval == .daily {
            params.append(URLQueryItem(name: "interval", value: "daily"))
        }
        
        return Resource(.coinsMarketChart, method: .GET, pathParam: base, params: params, completion: callback)
    }
}

// MARK: - Interval

extension Resources {
    
    enum Interval {
        case daily
        case minute
        
        func queryVal() -> String {
            return self == .daily ? "max" : "1"
        }
    }
}

// MARK: - IntervalOption

extension IntervalOption {

    var resources: Resources.Interval {
        switch self {
        case .minute:
            return .minute
        default:
            return .daily
        }
    }
}
