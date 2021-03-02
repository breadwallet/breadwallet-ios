//
//  AssetListWidget.swift
//  AssetListWidget
//
//  Created by stringcode on 11/02/2021.
//  Copyright © 2021 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import WidgetKit
import SwiftUI
import Intents

struct AssetListProvider: IntentTimelineProvider {
    
    typealias Entry = AssetListEntry
    typealias Intent = AssetListIntent

    let service: WidgetService = {
        DefaultWidgetService(widgetDataShareService: DefaultWidgetDataShareService(),
                             imageStoreService: DefaultImageStoreService())
    }()

    func placeholder(in context: Context) -> AssetListEntry {
        AssetListEntry(date: Date(), intent: AssetListIntent())
    }

    func getSnapshot(for configuration: AssetListIntent, in context: Context, completion: @escaping (AssetListEntry) -> Void) {
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
                entry = AssetListEntry(date: Date(),
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

    func getTimeline(for configuration: AssetListIntent, in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        getSnapshot(for: configuration, in: context) { entry in
            let timeline = Timeline(entries: [entry],
                policy: .after(Date().adding(minutes: 30)))
            completion(timeline)
        }
    }
}

struct AssetListEntry: TimelineEntry {
    let date: Date
    let viewModel: AssetListViewModel

    init(date: Date,
         intent: AssetListIntent,
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

        viewModel = AssetListViewModel(config: configuration,
                                       currencies: currencies,
                                       info: info,
                                       availableCurrencies: availableCurrencies)
    }
}

struct AssetListWidgetEntryView: View {
    var entry: AssetListProvider.Entry

    var body: some View {
        if entry.viewModel.anyAsset.isPlaceholder {
            AssetListView(viewModel: entry.viewModel)
                .redacted(reason: .placeholder)
        } else {
            AssetListView(viewModel: entry.viewModel)
        }
    }
}

struct AssetListWidget: Widget {
    let kind: String = "\(AssetListWidget.self)"

    var body: some WidgetConfiguration {
        IntentConfiguration(kind: kind,
                            intent: AssetListIntent.self,
                            provider: AssetListProvider()) { entry in
            AssetListWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(S.Widget.assetListTitle)
        .description(S.Widget.assetListDescription)
    }
}

struct AssetListWidget_Previews: PreviewProvider {

    static var previews: some View {

        let entry = AssetListEntry(date: Date(), intent: AssetListIntent())

        AssetListWidgetEntryView(entry: entry)
            .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
