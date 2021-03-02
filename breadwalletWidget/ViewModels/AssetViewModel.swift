//
//  AssetViewModel.swift
//  ChartDemo
//
//  Created by stringcode on 11/02/2021.
//  Copyright © 2021 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import Foundation
import SwiftUI

class AssetViewModel: Identifiable {
    let image: Image
    let ticker: String
    let name: String
    let price: String
    let pctChange: String
    let marketCap: String
    let updated: String
    let showUpdateTime: Bool
    let showSeparators: Bool
    let bgColor: [Color]
    let textColor: Color?
    let logoStyle: LogoStyle
    let chartUpColor: Color
    let chartDownColor: Color
    let chartViewModel: ChartViewModel
    let chartLocation: ChartLocation
    let urlScheme: URL
    let isPlaceholder: Bool

    init(image: Image,
         ticker: String,
         name: String,
         price: String,
         pctChange: String,
         marketCap: String,
         updated: String,
         showUpdateTime: Bool,
         showSeparators: Bool,
         bgColor: [Color],
         textColor: Color?,
         logoStyle: LogoStyle,
         chartUpColor: Color,
         chartDownColor: Color,
         chartViewModel: ChartViewModel,
         chartLocation: ChartLocation,
         urlScheme: URL,
         isPlaceholder: Bool) {

        self.image = image
        self.ticker = ticker
        self.name = name
        self.price = price
        self.pctChange = pctChange
        self.marketCap = marketCap
        self.updated = updated
        self.showUpdateTime = showUpdateTime
        self.showSeparators = showSeparators
        self.bgColor = bgColor
        self.textColor = textColor
        self.logoStyle = logoStyle
        self.chartUpColor = chartUpColor
        self.chartDownColor = chartDownColor
        self.chartViewModel = chartViewModel
        self.chartLocation = chartLocation
        self.urlScheme = urlScheme
        self.isPlaceholder = isPlaceholder
    }
}

// MARK: - Convenience initializer

extension AssetViewModel {

    convenience init(config: Configuration,
                     currency: Currency?,
                     info: MarketInfo?,
                     currencies: [Currency] = []) {
        let (textColor, bgColor) = AssetViewModel.textAndBgColors(config: config,
                                                                  currencies: currencies)
        self.init(
            image: AssetViewModel.image(currency: currency,
                                           logoStyle: config.logoStyle),
            ticker: currency?.code ?? "-",
            name: currency?.name ?? "-",
            price: AssetViewModel.formattedPrice(info?.price, config: config),
            pctChange: AssetViewModel.formattedPctChange(info?.change24hr),
            marketCap: info?.marketCap?.int.abbreviated ?? "-",
            updated: WidgetFormatter.time.string(from: Date()),
            showUpdateTime: config.showUpdatedTime,
            showSeparators: config.showSeparators,
            bgColor: bgColor,
            textColor: textColor,
            logoStyle: config.logoStyle,
            chartUpColor: config.chartUpColor?.color() ?? .green,
            chartDownColor: config.chartDownColor?.color() ?? .red,
            chartViewModel: ChartViewModel(
                candles: ChartViewModel.Candle.candles(info?.candles ?? []),
                greenCandle: config.chartUpColor?.color() ?? .green,
                redCandle: config.chartDownColor?.color() ?? .red,
                colorOverride: AssetViewModel.chartColorOverride(config: config,
                                                                 info: info)),
            chartLocation: config.chartLocation,
            urlScheme: AssetViewModel.urlScheme(for: currency),
            isPlaceholder: false)
    }
}

// MARK: - Utilities

extension AssetViewModel {
    
    var chartColor: Color {
        return chartViewModel.chartColor
    }
    
    func textColor(in colorScheme: ColorScheme) -> Color {
        var textColor = self.textColor ?? (colorScheme == .light ? .black : .white)
        let bgColor = backgroundColor(in: colorScheme)
        if textColor == bgColor {
            if textColor == .white {
                textColor = .black
            } else {
                textColor = .white
            }
        }
        return textColor
    }

    func backgroundColor(in colorScheme: ColorScheme) -> Color {
        return bgColor.first ?? (colorScheme == .light ? .white : .black)
    }

    func backgroundColors(in colorScheme: ColorScheme) -> [Color] {
        guard !bgColor.isEmpty else {
            return [backgroundColor(in: colorScheme),
                    backgroundColor(in: colorScheme)]
        }
        return bgColor
    }
        
    static func formattedPrice(_ price: Double?, config: Configuration) -> String {
        guard let price = price else {
            return "-"
        }
        let symbol = WidgetFormatter.currencySymbolByCode(config.quoteCurrencyCode)
        WidgetFormatter.price.currencySymbol = symbol
        WidgetFormatter.price.maximumFractionDigits = price > 999 ? 0 : 2
        return WidgetFormatter.price.string(from: NSNumber(value: price)) ?? "-"
    }
    
    static func formattedPctChange(_ pctChange: Double?) -> String {
        guard let pctChange = pctChange else {
            return "-"
        }
        if pctChange > 10 {
            WidgetFormatter.pctChange.maximumFractionDigits = 0
        } else if pctChange > 1 {
            WidgetFormatter.pctChange.maximumFractionDigits = 1
        } else {
            WidgetFormatter.pctChange.maximumFractionDigits = 2
        }
        let number = NSNumber(value: pctChange / 100)
        return WidgetFormatter.pctChange.string(from: number) ?? "-"
    }

    static func image(currency: Currency?, logoStyle: LogoStyle) -> Image {
        switch logoStyle {
        case .iconNoBackground:
            return currency?.noBgImage ?? Currency.placeholderImage
        default:
            return currency?.bgImage ?? Currency.placeholderImage
        }
    }
    
    static func chartColorOverride(config: Configuration, info: MarketInfo?) -> Color? {
        if info?.isChange24hrUp ?? true {
            return config.chartUpColor?.color() ?? .green
        }
        return config.chartDownColor?.color() ?? .red
    }
    
    static func textAndBgColors(config: Configuration,
                                currencies: [Currency]) -> (Color?, [Color]) {
        return (config.textColor?.color(), bgColors(config: config, currencies: currencies))
    }
    
    static func bgColors(config: Configuration,
                         currencies: [Currency]) -> [Color] {
        return config.backgroundColor?.colors(currencies: currencies) ?? []
    }
    
    static func urlScheme(for currency: Currency?) -> URL {
        let urlString = (currency?.urlSchemes?.first ?? "") + "://"
        return URL(string: urlString) ?? URL(string: "bread://")!
    }
}

// MARK: - Mock

extension AssetViewModel {

    enum MockType {
        case btc
        case eth
        case brd
    }

    static func mock(_ mockType: MockType = .btc) -> AssetViewModel {
         .init(image: Currency.placeholderImage,
               ticker: mockType.symbol(),
               name: mockType.name(),
               price: mockType.price(),
               pctChange: mockType.pctChange(),
               marketCap: mockType.marketCap(),
               updated: "14:45",
               showUpdateTime: false,
               showSeparators: true,
               bgColor: [],
               textColor: nil,
               logoStyle: .tickerAndName,
               chartUpColor: .green,
               chartDownColor: .red,
               chartViewModel: .mock(),
               chartLocation: .middle,
               urlScheme: URL(string: "bread://" + mockType.name().lowercased())!,
               isPlaceholder: true)
    }
}

extension AssetViewModel.MockType {

    func symbol() -> String {
        switch self {
        case .btc:
            return "BTC"
        case .eth:
            return "ETH"
        case .brd:
            return "BRD"
        }
    }

    func name() -> String {
        switch self {
        case .btc:
            return "Bitcoin"
        case .eth:
            return "Ethereum"
        case .brd:
            return "BRD"
        }
    }

    func price() -> String {
        switch self {
        case .btc:
            return "$49,493"
        case .eth:
            return "$1,800"
        case .brd:
            return "$0.13"
        }
    }

    func pctChange() -> String {
        switch self {
        case .btc:
            return "+49%"
        case .eth:
            return "+112%"
        case .brd:
            return "+5.6%"
        }
    }

    func marketCap() -> String {
        switch self {
        case .btc:
            return "836B"
        case .eth:
            return "345B"
        case .brd:
            return "89M"
        }
    }
}
