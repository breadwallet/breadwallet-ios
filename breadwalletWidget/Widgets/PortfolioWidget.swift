//
//  PortfolioWidget.swift
//  PortfolioWidget
//
//  Created by stringcode on 11/02/2021.
//  Copyright © 2021 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import WidgetKit
import SwiftUI
import Intents

struct PortfolioProvider: IntentTimelineProvider {
    
    typealias Entry = PortfolioEntry
    typealias Intent = PortfolioIntent
    
    let service: WidgetService = {
        DefaultWidgetService(widgetDataShareService: DefaultWidgetDataShareService(),
                             imageStoreService: DefaultImageStoreService())
    }()
    
    func placeholder(in context: Context) -> PortfolioEntry {
        PortfolioEntry(date: Date(), intent: PortfolioIntent())
    }

    func getSnapshot(for configuration: PortfolioIntent, in context: Context, completion: @escaping (PortfolioEntry) -> Void) {
        guard let assets = configuration.assets else {
            completion(placeholder(in: context))
            return
        }

        let quote = service.quoteCurrencyCode()
        let interval = configuration.interval
        service.fetchCurrenciesAndMarketInfo(for: assets,
                                             quote: quote.lowercased(),
                                             interval: interval) { result in
            let entry: Entry

            switch result {
            case let .success((currencies, info)):
                entry = PortfolioEntry(date: Date(),
                                       intent: configuration,
                                       currencies: currencies,
                                       quoteCurrencyCode: quote,
                                       info: info,
                                       availableCurrencies: (try? service.defaultCurrencies()) ?? [])
            case let .failure(error):
                print(error)
                entry = placeholder(in: context)
            }

            DispatchQueue.main.async {
                completion(entry)
            }
        }
    }

    func getTimeline(for configuration: PortfolioIntent, in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        getSnapshot(for: configuration, in: context) { entry in
            let timeline = Timeline(entries: [entry],
                policy: .after(Date().adding(minutes: 30)))
            completion(timeline)
        }
    }
}

struct PortfolioEntry: TimelineEntry {
    let date: Date
    let viewModel: PortfolioViewModel

    init(date: Date,
         intent: PortfolioIntent,
         currencies: [Currency] = [],
         quoteCurrencyCode: String = "USD",
         info: [CurrencyId: MarketInfo] = [:],
         availableCurrencies: [Currency] = []) {

        self.date = date

        guard !currencies.isEmpty && !info.isEmpty else {
            viewModel = .mock()
            return
        }
        
        let configuration = Configuration(intent: intent,
                                          quoteCurrencyCode: quoteCurrencyCode)

        viewModel = PortfolioViewModel(config: configuration,
                                       currencies: currencies,
                                       info: info,
                                       availableCurrencies: availableCurrencies)
    }
}

struct PortfolioWidgetEntryView: View {
    var entry: PortfolioProvider.Entry

    var body: some View {
        if entry.viewModel.assetList.anyAsset.isPlaceholder {
            PortfolioView(viewModel: entry.viewModel)
                .redacted(reason: .placeholder)
        } else {
            PortfolioView(viewModel: entry.viewModel)
        }
    }
}

struct PortfolioWidget: Widget {
    let kind: String = "\(PortfolioWidget.self)"

    var body: some WidgetConfiguration {
        IntentConfiguration(kind: kind,
                            intent: PortfolioIntent.self,
                            provider: PortfolioProvider()) { entry in
            PortfolioWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(S.Widget.portfolioTitle)
        .description(S.Widget.portfolioDescription)
    }
}

struct PortfolioWidget_Previews: PreviewProvider {
    static var previews: some View {

        let entry = PortfolioEntry(date: Date(), intent: PortfolioIntent())

        PortfolioWidgetEntryView(entry: entry)
            .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
