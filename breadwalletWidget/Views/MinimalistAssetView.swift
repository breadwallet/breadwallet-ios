//
//  AssetView.swift
//  ChartDemo
//
//  Created by stringcode on 15/02/2021.
//  Copyright © 2021 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import SwiftUI
import WidgetKit

struct MinimalistAssetView: View {

    @State var viewModel: AssetViewModel

    @Environment(\.widgetFamily) var widgetFamily: WidgetFamily
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    
    var body: some View {
        ZStack {
            ChartView(viewModel: viewModel.chartViewModel)
            HStack {
                VStack(alignment: .leading, spacing: 1.0) {
                    Text(viewModel.price)
                        .font(priceFont())
                        .foregroundColor(viewModel.chartColor)
                        .background(
                            Rectangle()
                                .foregroundColor(viewModel.backgroundColor(in: colorScheme))
                                .opacity(0.75)
                                .cornerRadius(8)
                        )
                    if viewModel.showUpdateTime {
                        UpdateTimeView(
                            updated: viewModel.updated,
                            iconFont: .system(.caption2),
                            textFont: .system(.caption2)
                        )
                        .foregroundColor(viewModel.chartColor)
                        .opacity(0.75)
                        .background(
                            Rectangle()
                                .foregroundColor(viewModel.backgroundColor(in: colorScheme))
                                .opacity(0.75)
                                .cornerRadius(4)
                        )
                    }
                    Spacer()
                }
                Spacer()
            }
            .padding()
        }
        .background(viewModel.backgroundColor(in: colorScheme))
    }
}

// MARK: - Helpers

private extension MinimalistAssetView {
    
    func priceFont() -> Font {
        switch widgetFamily {
        case .systemLarge:
            return .largeTitle
        case .systemMedium:
            return .title
        default:
            return .title2
        }
    }
}

// MARK: - Previews

struct MinimalistAssetView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            MinimalistAssetView(viewModel: .mock())
                .previewContext(WidgetPreviewContext(family: .systemSmall))
            MinimalistAssetView(viewModel: .mock())
                .previewContext(WidgetPreviewContext(family: .systemMedium))
            MinimalistAssetView(viewModel: .mock())
                .previewContext(WidgetPreviewContext(family: .systemLarge))
        }
    }
}
