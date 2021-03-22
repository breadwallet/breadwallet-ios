//
//  PortfolioViewModel.swift
//  ChartDemo
//
//  Created by stringcode on 11/02/2021.
//  Copyright © 2021 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//
import Foundation
import SwiftUI

struct PortfolioViewModel {
    let assetList: AssetListViewModel
    let portfolioValue: String
    let portfolioPctChange: String
    let title: String
    let color: Color
}

// MARK: - Convenience initializer

extension PortfolioViewModel {
    
    init(config: Configuration,
         currencies: [Currency],
         info: [CurrencyId: MarketInfo],
         availableCurrencies: [Currency]) {
        assetList = .init(config: config,
                          currencies: currencies,
                          info: info,
                          availableCurrencies: availableCurrencies)
        let (value, pctChange) = PortfolioViewModel.portfolioValues(info: info)
        let portfolio = PortfolioViewModel.formattedPortfolio(value: value,
                                                              pctChange: pctChange,
                                                              currencyCode: config.quoteCurrencyCode)
        let asset = assetList.anyAsset
        let hasAmount = info.values.first?.amount != nil
        portfolioValue = portfolio.0
        portfolioPctChange = portfolio.1
        title = hasAmount ? S.Widget.portfolioSummary : S.Widget.enablePortfolio
        color = pctChange < 0 ? asset.chartDownColor : asset.chartUpColor}
}

// MARK: - Value computation

private extension PortfolioViewModel {

    static func portfolioValues(info: [CurrencyId: MarketInfo]) -> (Double, Double) {
        var values = [Double]()
        var pctValues = [Double]()

        info.forEach { (_, value) in
            if let amount = value.amount {
                values.append(value.price * amount)
                pctValues.append(value.change24hr ?? 0)
            }
        }

        let total = values.reduce(0, +)
        let weights = values.map { $0 / total }
        let pctChange = weightedAverage(values: pctValues, weights: weights)

        return (total, pctChange.isNaN ? 0 : pctChange)
    }

    static func formattedPortfolio(value: Double,
                                   pctChange: Double,
                                   currencyCode: String) -> (String, String) {

        WidgetFormatter.price.currencyCode = currencyCode
        WidgetFormatter.price.maximumFractionDigits = value > 999 ? 0 : 2

        if pctChange > 10 {
            WidgetFormatter.pctChange.maximumFractionDigits = 0
        } else if pctChange > 1 {
            WidgetFormatter.pctChange.maximumFractionDigits = 1
        } else {
            WidgetFormatter.pctChange.maximumFractionDigits = 2
        }

        let valueNumber = NSNumber(value: value)
        let pctNumber = NSNumber(value: pctChange / 100)

        return (WidgetFormatter.price.string(from: valueNumber) ?? "-",
                WidgetFormatter.pctChange.string(from: pctNumber) ?? "-")
    }

    static func weightedAverage(values: [Double], weights: [Double]) -> Double {
        guard !values.isEmpty && values.count == weights.count else {
            return 0
        }

        let totalWeight = weights.reduce(0.0, +)

        return zip(values, weights)
            .map { $0 * $1 }
            .reduce(0.0, +) / totalWeight
    }
}

// MARK: - Mock

extension PortfolioViewModel {

    static func mock() -> PortfolioViewModel {
        return .init(assetList: .mock(),
                     portfolioValue: "$104,234",
                     portfolioPctChange: "+87%",
                     title: S.Widget.portfolioSummary,
                     color: .green)
    }
}
