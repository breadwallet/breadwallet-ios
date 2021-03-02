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

@main
struct BreadWalletWidgetBundle: WidgetBundle {
    @WidgetBundleBuilder
    var body: some Widget {
        AssetWidget()
        AssetListWidget()
        PortfolioWidget()
    }
}

struct BreadWalletWidgetBundle_Previews: PreviewProvider {
    static var previews: some View {
        
        let entry = AssetEntry(date: Date(), intent: AssetIntent())
        
        AssetWidgetEntryView(entry: entry)
            .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
