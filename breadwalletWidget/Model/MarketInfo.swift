//
//  MarketInfo.swift
//  breadwallet
//
//  Created by stringcode on 11/02/2021.
//  Copyright © 2021 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//
import Foundation
import CoinGecko

struct MarketInfo {
    let id: CurrencyId
    let price: Double
    let amount: Double?
    let marketCap: Double?
    let vol24hr: Double?
    let change24hr: Double?
    let lastUpdatedAt: Int?
    let candles: [Candle]
}

// MARK: - Convenience initializer

extension MarketInfo {

    init(id: CurrencyId,
         amount: Double?,
         simplePrice: SimplePrice,
         chart: MarketChart?) {
        self.id = id
        self.price = simplePrice.price
        self.amount = amount
        self.marketCap = simplePrice.marketCap
        self.vol24hr = simplePrice.vol24hr
        self.change24hr = simplePrice.change24hr
        self.lastUpdatedAt = simplePrice.lastUpdatedAt
        self.candles = chart?.dataPoints.map {
            .init(uniformPrice: $0.price.float, timestamp: $0.timestamp)
        } ?? []
    }
}

// MARK: - Utilities

extension MarketInfo {
    
    var isChange24hrUp: Bool {
        return (change24hr ?? 0) < 0 ? false : true
    }
}

// MARK: - MarketInfo.Candle

extension MarketInfo {

    struct Candle {
        let open: Float
        let close: Float
        let high: Float
        let low: Float
        let timestamp: Int
        
        // Convenience init
        init(uniformPrice: Float, timestamp: Int) {
            open = uniformPrice
            close = uniformPrice
            high = uniformPrice
            low = uniformPrice
            self.timestamp = timestamp
        }
    }
}
