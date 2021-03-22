//
//  PortfolioView.swift
//  breadwalletWidgetExtension
//
//  Created by stringcode on 15/02/2021.
//  Copyright © 2021 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import SwiftUI
import WidgetKit

struct PortfolioView: View {

    @State var viewModel: PortfolioViewModel
    
    @Environment(\.widgetFamily) var widgetFamily: WidgetFamily
    @Environment(\.colorScheme) var colorScheme: ColorScheme

    var body: some View {
        let textColor = viewModel.assetList.anyAsset.textColor(in: colorScheme)
        if viewModel.assetList.assets.count <= 1 {
            AssetView(viewModel: viewModel.assetList.anyAsset)
        } else {
            ZStack {
                VStack {
                    switch widgetFamily {
                    case .systemLarge:
                        AssetListGridView(
                            viewModel: viewModel.assetList,
                            singleColumnLimit: 4,
                            doubleColumnLimit: 12
                        )
                        BetterDivider(viewModel: viewModel.assetList.anyAsset)
                        PortfolioItemView(viewModel: viewModel)
                    case .systemMedium:
                        AssetListGridView(
                            viewModel: viewModel.assetList,
                            singleColumnLimit: 2,
                            doubleColumnLimit: 4
                        )
                        BetterDivider(viewModel: viewModel.assetList.anyAsset)
                        PortfolioItemView(viewModel: viewModel)

                    case .systemSmall:
                        PortfolioItemView(viewModel: viewModel)
                        BetterDivider(viewModel: viewModel.assetList.anyAsset)
                        AssetListGridView(
                            viewModel: viewModel.assetList,
                            singleColumnLimit: 2,
                            doubleColumnLimit: 2
                        )
                    default:
                        Text("Not supported")
                    }
                }
                .padding()

                // Update time stamps
                if viewModel.assetList.anyAsset.showUpdateTime {
                    PaddedUpdateTimeView(viewModel: viewModel.assetList.anyAsset)
                }
            }
            .background(BackgroundView(viewModel: viewModel.assetList.anyAsset))
        }
    }
}

struct PortfolioItemView: View {
    
    @State var viewModel: PortfolioViewModel
    
    @Environment(\.widgetFamily) var widgetFamily: WidgetFamily

    var body: some View {
        HStack(alignment: .top) {
            if widgetFamily != .systemSmall {
                Spacer()
                    .frame(maxWidth: 160)
            }
            Text(viewModel.title)
                .font(.footnote)
                .lineLimit(2)
                .opacity(0.7)
                .scaledToFill()
                .allowsTightening(true)
                .minimumScaleFactor(0.75)
            
            Spacer()

            VStack(alignment: .trailing) {
                Text(viewModel.portfolioValue)
                    .font(.footnote)
                    .bold()
                    .scaledToFill()
                Text(viewModel.portfolioPctChange)
                    .foregroundColor(viewModel.color)
                    .font(.footnote)
                    .bold()
                    .scaledToFill()
            }
            
        }
    }
}

struct PortfolioView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            PortfolioView(viewModel: .mock())
                .previewContext(WidgetPreviewContext(family: .systemSmall))
            PortfolioView(viewModel: .mock())
                .previewContext(WidgetPreviewContext(family: .systemMedium))
            PortfolioView(viewModel: .mock())
                .previewContext(WidgetPreviewContext(family: .systemLarge))
        }    }
}
