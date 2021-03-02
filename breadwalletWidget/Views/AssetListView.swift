//
//  AssetListView.swift
//  breadwalletWidgetExtension
//
//  Created by stringcode on 15/02/2021.
//  Copyright © 2021 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import SwiftUI
import WidgetKit

struct AssetListView: View {

    @State var viewModel: AssetListViewModel
    
    @Environment(\.widgetFamily) var widgetFamily: WidgetFamily
    @Environment(\.colorScheme) var colorScheme: ColorScheme

    var body: some View {
        if viewModel.assets.count <= 1 {
            AssetView(viewModel: viewModel.anyAsset)
        } else {
            ZStack {
                VStack {
                    switch widgetFamily {
                    case .systemLarge:
                        AssetListGridView(
                            viewModel: viewModel,
                            singleColumnLimit: 4,
                            doubleColumnLimit: 12
                        )
                    case .systemMedium:
                        AssetListGridView(
                            viewModel: viewModel,
                            singleColumnLimit: 3,
                            doubleColumnLimit: 6
                        )
                    case .systemSmall:
                        AssetListGridView(
                            viewModel: viewModel,
                            singleColumnLimit: 3,
                            doubleColumnLimit: 3
                        )
                    default:
                        Text("Not supported")
                    }
                }
                .padding()

                // Update time stamps
                if viewModel.anyAsset.showUpdateTime {
                    PaddedUpdateTimeView(viewModel: viewModel.anyAsset)
                }
            }
            .background(BackgroundView(viewModel: viewModel.anyAsset))
        }
    }
}

// MARK: - AssetListGridView

struct AssetListGridView: View {

    @State var viewModel: AssetListViewModel
    @State var singleColumnLimit: Int
    @State var doubleColumnLimit: Int
    
    @Environment(\.widgetFamily) var widgetFamily: WidgetFamily
    @Environment(\.colorScheme) var colorScheme: ColorScheme

    var body: some View {
        let forceSingleColumn = singleColumnLimit == doubleColumnLimit
        if viewModel.assets.count <= singleColumnLimit || forceSingleColumn {
            
            ForEach(0..<singleColumnLimit) { idx in
                if idx < viewModel.assets.count {
                    AssetListItemView(
                        viewModel: viewModel.assets[idx],
                        showAssetDescription: widgetFamily != .systemSmall
                    )
                }
                if idx < min(viewModel.assets.count - 1, singleColumnLimit - 1) {
                    if viewModel.anyAsset.showSeparators {
                        BetterDivider(color: viewModel.anyAsset.textColor(in: colorScheme))
                    }
                }
            }
        
        } else {
            
            let count = min(
                ceil(Float(viewModel.assets.count) / 2).int,
                doubleColumnLimit / 2
            )
            
            ForEach(0..<count) { idx in
                HStack {
                    if idx * 2 < viewModel.assets.count {
                        AssetListItemView(viewModel: viewModel.assets[idx * 2])
                            .frame(maxWidth: .infinity)
                    } else {
                        Spacer()
                            .frame(maxWidth: .infinity)
                    }
                    
                    Spacer().frame(width: 20)
                    
                    if idx * 2 + 1 < viewModel.assets.count {
                        AssetListItemView(viewModel: viewModel.assets[idx * 2 + 1])
                            .frame(maxWidth: .infinity)
                    } else {
                        Spacer()
                            .frame(maxWidth: .infinity)
                    }
                }
                if idx < count - 1 {
                    if viewModel.anyAsset.showSeparators {
                        BetterDivider(color: viewModel.anyAsset.textColor(in: colorScheme))
                    }
                }
            }
        }
    }
}

// MARK: - AssetListItemView

struct AssetListItemView: View {

    @State var viewModel: AssetViewModel
    @State var showAssetDescription: Bool = false
    
    @Environment(\.widgetFamily) var widgetFamily: WidgetFamily
    @Environment(\.colorScheme) var colorScheme: ColorScheme

    var body: some View {
        Link(destination: viewModel.urlScheme) {
            HStack {
                // Icon / Title
                LogoView(viewModel: viewModel)
                    .frame(
                        maxWidth: viewModel.logoStyle.isImageStyle() ? 26 : 60,
                        maxHeight: viewModel.logoStyle.isImageStyle() ? 26 : 40
                    )
                    .scaledToFit()
                    .minimumScaleFactor(0.1)
                    .allowsTightening(true)
                    .foregroundColor(viewModel.textColor(in: colorScheme))
                
                if showAssetDescription && viewModel.logoStyle.isImageStyle() {
                    AssetDescriptionView(viewModel: viewModel)
                }

                if viewModel.chartLocation == .middle {
                    ChartView(viewModel: viewModel.chartViewModel)
                }

                if viewModel.chartLocation == .none {
                    Spacer()
                }
                
                VStack(alignment: .trailing) {
                    Text(viewModel.price)
                        .foregroundColor(viewModel.textColor(in: colorScheme))
                        .font(.footnote)
                        .multilineTextAlignment(.leading)
                        .lineLimit(1)
                        .allowsTightening(true)
                        .minimumScaleFactor(0.9)
                        .scaledToFill()
                    Text(viewModel.pctChange)
                        .foregroundColor(viewModel.chartViewModel.chartColor)
                        .font(.caption2)
                        .allowsTightening(true)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .scaledToFit()
                        .frame(minHeight: 14)
                }.frame(width: 44)

                if viewModel.chartLocation == .trailing {
                    ChartView(viewModel: viewModel.chartViewModel)
                }
            }
        }
    }
}

struct AssetListView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            AssetListView(viewModel: .mock())
                .previewContext(WidgetPreviewContext(family: .systemSmall))
            AssetListView(viewModel: .mock())
                .previewContext(WidgetPreviewContext(family: .systemMedium))
            AssetListView(viewModel: .mock())
                .previewContext(WidgetPreviewContext(family: .systemLarge))
        }    }
}
