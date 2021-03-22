//
//  AssetWidget.swift
//  AssetWidget
//
//  Created by stringcode on 11/02/2021.
//  Copyright © 2021 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import WidgetKit
import SwiftUI
import Intents

struct AssetProvider: IntentTimelineProvider {
    typealias Entry = AssetEntry
    typealias Intent = AssetIntent

    let service: WidgetService = {
        DefaultWidgetService(widgetDataShareService: DefaultWidgetDataShareService(),
                             imageStoreService: DefaultImageStoreService())
    }()

    func placeholder(in context: Context) -> AssetEntry {
        return AssetEntry(date: Date(), viewModel: .mock())
    }

    func getSnapshot(for configuration: AssetIntent, in context: Context, completion: @escaping (AssetEntry) -> Void) {
        guard let asset = configuration.asset else {
            completion(placeholder(in: context))
            return
        }

        let quote = service.quoteCurrencyCode()
        let interval = configuration.interval
        service.fetchCurrenciesAndMarketInfo(for: [asset],
                                             quote: quote.lowercased(),
                                             interval: interval) { result in
            let entry: Entry
                
            switch result {
            case let .success((currencies, info)):
                entry = AssetEntry(date: Date(),
                                   intent: configuration,
                                   currency: currencies.first,
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

    func getTimeline(for configuration: AssetIntent, in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        getSnapshot(for: configuration, in: context) { entry in
            let timeline = Timeline(entries: [entry],
                                    policy: .after(Date().adding(minutes: 30)))
            completion(timeline)
        }
    }
}

struct AssetEntry: TimelineEntry {
    let date: Date
    let viewModel: AssetViewModel
    let isMinimalist: Bool
    
    init(date: Date,
         intent: AssetIntent,
         currency: Currency? = nil,
         quoteCurrencyCode: String = "USD",
         info: [CurrencyId: MarketInfo] = [:],
         availableCurrencies: [Currency] = []) {

        self.date = date
        self.isMinimalist = intent.style == StyleOption.minimalist

        guard let currency = currency, !info.isEmpty else {
            viewModel = .mock()
            return
        }
        
        let configuration = Configuration(intent: intent,
                                          quoteCurrencyCode: quoteCurrencyCode)
        viewModel = AssetViewModel(config: configuration,
                                   currency: currency,
                                   info: info[currency.uid],
                                   currencies: availableCurrencies)
    }
    
    init(date: Date, viewModel: AssetViewModel) {
        self.date = date
        self.viewModel = .mock()
        self.isMinimalist = false
    }
}

struct AssetWidgetEntryView: View {
    @State var entry: AssetProvider.Entry

    var body: some View {
        if entry.isMinimalist {
            if entry.viewModel.isPlaceholder {
                MinimalistAssetView(viewModel: entry.viewModel)
                    .redacted(reason: .placeholder)
            } else {
                MinimalistAssetView(viewModel: entry.viewModel)
            }
        } else {
            if entry.viewModel.isPlaceholder {
                AssetView(viewModel: entry.viewModel)
                    .redacted(reason: .placeholder)
            } else {
                AssetView(viewModel: entry.viewModel)
            }
        }
    }
}

struct AssetWidget: Widget {
    let kind: String = "\(AssetWidget.self)"

    var body: some WidgetConfiguration {
        IntentConfiguration(kind: kind,
                            intent: AssetIntent.self,
                            provider: AssetProvider()) { entry in
            AssetWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(S.Widget.assetTitle)
        .description(S.Widget.assetDescription)
    }
}

struct AssetWidget_Previews: PreviewProvider {
    static var previews: some View {
        
        let entry = AssetEntry(date: Date(), viewModel: .mock())

        Group {
            AssetWidgetEntryView(entry: entry)
                .colorScheme(.light)
                .previewContext(WidgetPreviewContext(family: .systemSmall))
            
            AssetWidgetEntryView(entry: entry)
                .colorScheme(.dark)
                .previewContext(WidgetPreviewContext(family: .systemSmall))
        }
    }
}
