//
//  ChartViewModel.swift
//  ChartDemo
//
//  Created by stringcode on 11/02/2021.
//  Copyright © 2021 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import Foundation
import SwiftUI

struct ChartViewModel {
    let candles: [Candle]
    let greenCandle: Color
    let redCandle: Color
    let colorOverride: Color?
    
    var chartColor: Color {
        if let color = colorOverride {
            return color
        }
        guard candles.count > 1 else {
            return greenCandle
        }
        let rising = candles[candles.count - 1].close >= candles[candles.count - 2].close
        return rising ? greenCandle : redCandle
    }
}

// MARK: - Candle

extension ChartViewModel {
    
    struct Candle {
        let open: Float
        let close: Float
        let high: Float
        let low: Float
    }
}

// MARK: - Default mock

extension ChartViewModel {
    
    static func mock(_ count: Int = 30, greenCandle: Color = .green, redCandle: Color = .red) -> ChartViewModel {
        guard let url = Bundle.main.url(forResource: "mock-candles", withExtension: "json") else {
            fatalError("mock-candles.json not found")
        }
        
        guard let data = try? Data(contentsOf: url) else {
            fatalError("could not load data from mock-candles.json")
        }
        
        guard let candles = try? JSONDecoder().decode([ChartViewModel.Candle].self, from: data) else {
            fatalError("could not decode data from mock-candles.json")
        }
        
        return .init(candles: normalized(candles),
                     greenCandle: greenCandle,
                     redCandle: redCandle,
                     colorOverride: nil)
    }
    
    static func normalized(_ candles: [ChartViewModel.Candle]) -> [Candle] {
        let high = candles.sorted { $0.high > $1.high }.first?.high ?? 1
        let low = candles.sorted { $0.low < $1.low }.first?.low ?? 0
        let delta = high - low
        
        return candles.map {
            return .init(
                open: ($0.open - low) / delta,
                close: ($0.close - low) / delta,
                high: ($0.high - low) / delta,
                low: ($0.low - low) / delta
            )
        }
    }
}

// MARK: - ChartViewModel.Candle Decodable

extension ChartViewModel.Candle: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case open
        case high
        case low
        case close
    }

    init(from decoder: Decoder) throws {
        let cont = try decoder.container(keyedBy: CodingKeys.self)
        open = try (try cont.decode(String.self, forKey: .open)).float()
        high = try (try cont.decode(String.self, forKey: .high)).float()
        low = try (try cont.decode(String.self, forKey: .low)).float()
        close = try (try cont.decode(String.self, forKey: .close)).float()
    }
}

// MARK: - MarketInfo.Candle

extension ChartViewModel.Candle {
    
    static func candles(_ candles: [MarketInfo.Candle]) -> [ChartViewModel.Candle] {
        var bounded = candles
        if candles.count > 90 {
            bounded = Array(candles[candles.count-90..<candles.count])
        }
        let chartCandles: [ChartViewModel.Candle] = bounded.map {
            .init(open: $0.open, close: $0.close, high: $0.high, low: $0.low)
        }
        return ChartViewModel.normalized(chartCandles)
    }
}
