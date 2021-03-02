//
//  AssetView.swift
//  ChartDemo
//
//  Created by stringcode on 11/02/2021.
//  Copyright © 2021 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import SwiftUI
import WidgetKit

struct AssetView: View {

    @State var viewModel: AssetViewModel

    @Environment(\.widgetFamily) var widgetFamily: WidgetFamily

    var body: some View {
        switch widgetFamily {
        case .systemMedium:
            AssetViewMedium(viewModel: viewModel)
        case .systemLarge:
            AssetViewLarge(viewModel: viewModel)
        default:
            AssetViewSmall(viewModel: viewModel)
        }
    }
}

struct AssetViewSmall: View {

    @State var viewModel: AssetViewModel
    
    @Environment(\.colorScheme) var colorScheme: ColorScheme
        
    var body: some View {
        ZStack {
            VStack {
                HStack(alignment: .top, spacing: 2) {
                    
                    // Icon / Title
                    LogoView(viewModel: viewModel)
                    
                    Spacer()
                    
                    // Detail pct change / market cap / refresh time
                    InfoView(viewModel: viewModel)
                }
                .allowsTightening(true)
                .minimumScaleFactor(0.9)
                .padding([.horizontal], 0)
                
                // Chart
                ChartView(viewModel: viewModel.chartViewModel)
                    .frame(minHeight: viewModel.showUpdateTime ? 32 : 38)

                // Price
                Text(viewModel.price)
                    .font(.title)
                    .multilineTextAlignment(.leading)
                    .lineLimit(1)
                    .scaledToFill()
                    .foregroundColor(viewModel.textColor(in: colorScheme))
            }
            .padding()
        }
        .background(BackgroundView(viewModel: viewModel))
        .widgetURL(viewModel.urlScheme)
    }
}

// MARK: - AssetViewMedium

struct AssetViewMedium: View {

    @State var viewModel: AssetViewModel

    @Environment(\.colorScheme) var colorScheme: ColorScheme
        
    var body: some View {
        ZStack {
            HStack {
                VStack(alignment: .leading) {
                    HStack(alignment: .top, spacing: 2) {
                        
                        // Icon / Title
                        LogoView(viewModel: viewModel)
                            .frame(maxWidth: 65, maxHeight: 65)
                            .scaledToFill()
                    
                        Spacer()
                        
                        // Detail pct change / market cap / refresh time
                        InfoView(viewModel: viewModel)
                    }
                    .allowsTightening(true)
                    .minimumScaleFactor(0.9)

                    if !viewModel.logoStyle.isImageStyle() {
                      Spacer()
                    }
                    
                    // Price
                    Text(viewModel.price)
                        .font(.title)
                        .multilineTextAlignment(.leading)
                        .lineLimit(1)
                        .scaledToFill()
                        .foregroundColor(viewModel.textColor(in: colorScheme))
                }
                
                // Chart
                ChartView(viewModel: viewModel.chartViewModel)
                    .frame(minHeight: 38)
            }
            .padding()
        }
        .background(BackgroundView(viewModel: viewModel))
        .widgetURL(viewModel.urlScheme)
    }
}

// MARK: - AssetViewLarge

struct AssetViewLarge: View {

    @State var viewModel: AssetViewModel

    @Environment(\.colorScheme) var colorScheme: ColorScheme
    
    var body: some View {
        ZStack {
            VStack {
                VStack(alignment: .leading) {
                    HStack(alignment: .top) {
                        
                        // Icon / Title
                        LogoView(viewModel: viewModel)
                            .frame(maxWidth: 95, maxHeight: 95)
                            .scaledToFill()
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            
                            // Price
                            Text(viewModel.price)
                                .font(.title)
                                .multilineTextAlignment(.leading)
                                .lineLimit(1)
                                .scaledToFill()
                                .foregroundColor(viewModel.textColor(in: colorScheme))
                            
                            // Detail pct change / market cap / refresh time
                            InfoView(viewModel: viewModel)
                        }
                    }
                    .allowsTightening(true)
                    .minimumScaleFactor(0.9)
 
                    // Chart
                    ChartView(viewModel: viewModel.chartViewModel)
                        .frame(minHeight: 38)
                }
            }
            .padding()
        }
        .background(BackgroundView(viewModel: viewModel))
        .widgetURL(viewModel.urlScheme)
    }
}

// MARK: - Previews

struct AssetView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            AssetView(viewModel: .mock())
                .previewContext(WidgetPreviewContext(family: .systemSmall))
            AssetView(viewModel: .mock())
                .previewContext(WidgetPreviewContext(family: .systemMedium))
            AssetView(viewModel: .mock())
                .previewContext(WidgetPreviewContext(family: .systemLarge))
        }
    }
}
