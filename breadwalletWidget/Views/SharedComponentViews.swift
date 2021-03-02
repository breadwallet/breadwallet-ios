//
//  SharedComponentViews.swift
//  breadwalletWidgetExtension
//
//  Created by stringcode on 15/02/2021.
//  Copyright © 2021 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import SwiftUI
import WidgetKit

struct LogoView: View {

    @State var viewModel: AssetViewModel

    @Environment(\.colorScheme) var colorScheme: ColorScheme
    @Environment(\.widgetFamily) var widgetFamily: WidgetFamily

    var body: some View {
        switch viewModel.logoStyle {
        case .iconWithBackground, .iconNoBackground:
            viewModel.image
                .resizable()
                .aspectRatio(contentMode: .fit)
                .scaledToFit()
                .foregroundColor(viewModel.textColor(in: colorScheme))
        case .ticker:
            VStack(alignment: .leading) {
                Text(viewModel.ticker)
                    .font(tickerFont())
            }
                .foregroundColor(viewModel.textColor(in: colorScheme))
        case .tickerAndName:
            VStack(alignment: .leading) {
                Text(viewModel.ticker)
                    .font(tickerFont())
                Text(viewModel.name)
                    .font(nameFont())
                    .opacity(0.7)
                    .minimumScaleFactor(0.25)
                    .allowsTightening(true)
            }
                .foregroundColor(viewModel.textColor(in: colorScheme))
        case .unknown:
            Text("")
        }
    }

    func tickerFont() -> Font {
        switch widgetFamily {
        case .systemLarge, .systemMedium:
            return .system(.largeTitle)
        default:
            return .system(.title3)
        }
    }

    func nameFont() -> Font {
        switch widgetFamily {
        case .systemLarge, .systemMedium:
            return .system(.title)
        default:
            return .system(.body)
        }
    }
}

struct BackgroundView: View {

    @State var viewModel: AssetViewModel

    @Environment(\.colorScheme) var colorScheme: ColorScheme

    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    gradient: Gradient(
                        colors: viewModel.backgroundColors(in: colorScheme)
                    ),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }
}

struct InfoView: View {

    @State var viewModel: AssetViewModel

    @Environment(\.colorScheme) var colorScheme: ColorScheme
    @Environment(\.widgetFamily) var widgetFamily: WidgetFamily

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(viewModel.pctChange)
                .foregroundColor(viewModel.chartColor)
                .font(pctChangeFont())
                .lineLimit(1)
            Text(viewModel.marketCap)
                .foregroundColor(viewModel.textColor(in: colorScheme))
                .font(marketCapFont())
                .lineLimit(1)
                .opacity(0.7)
            if viewModel.showUpdateTime {
                UpdateTimeView(
                    updated: viewModel.updated,
                    iconFont: updatedIconFont(),
                    textFont: updatedFont()
                )
                .foregroundColor(viewModel.textColor(in: colorScheme))
                .opacity(0.7)
            }
        }
    }

    func pctChangeFont() -> Font {
        switch widgetFamily {
        case .systemLarge, .systemMedium:
            return .system(.body)
        default:
            return .system(.footnote)
        }
    }

    func marketCapFont() -> Font {
        switch widgetFamily {
        case .systemLarge, .systemMedium:
            return .system(.body)
        default:
            return .system(.caption2)
        }
    }

    func updatedFont() -> Font {
        switch widgetFamily {
        case .systemLarge, .systemMedium:
            return .system(.body)
        default:
            return .system(.caption2)
        }
    }

    func updatedIconFont() -> Font {
        switch widgetFamily {
        case .systemLarge, .systemMedium:
            return .system(size: 13)
        default:
            return .system(size: 8)
        }
    }
}

struct UpdateTimeView: View {

    @State var updated: String
    @State var iconFont: Font
    @State var textFont: Font

    @Environment(\.colorScheme) var colorScheme: ColorScheme

    var body: some View {
        HStack(spacing: 2.0) {
            Image(systemName: "arrow.clockwise")
                .font(iconFont)
                .allowsTightening(true)
                .minimumScaleFactor(0.7)
            Text(updated)
                .lineLimit(1)
                .font(textFont)
                .allowsTightening(true)
                .minimumScaleFactor(0.7)
        }
    }
}

struct PaddedUpdateTimeView: View {

    @State var viewModel: AssetViewModel

    @Environment(\.colorScheme) var colorScheme: ColorScheme

    var body: some View {
        HStack {
            Spacer()
            VStack {
                UpdateTimeView(
                    updated: viewModel.updated,
                    iconFont: .system(size: 5),
                    textFont: .system(size: 7)
                )
                    .foregroundColor(viewModel.textColor(in: colorScheme))
                    .opacity(0.7)
                    .padding(.top, 5.0)
                    .padding(.trailing, 15.0)
                Spacer()
            }
        }
    }
}

struct AssetDescriptionView: View {

    @State var viewModel: AssetViewModel

    @Environment(\.widgetFamily) var widgetFamily: WidgetFamily
    @Environment(\.colorScheme) var colorScheme: ColorScheme

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(viewModel.ticker)
                    .font(.footnote)
                    .lineLimit(1)
                    .opacity(1)
                    .foregroundColor(viewModel.textColor(in: colorScheme))
                Text(viewModel.name)
                    .font(.caption)
                    .lineLimit(1)
                    .allowsTightening(true)
                    .minimumScaleFactor(0.5)
                    .opacity(0.7)
                    .foregroundColor(viewModel.textColor(in: colorScheme))
            }
            Spacer()
        }
            .frame(minWidth: 60)
            .scaledToFit()
    }
}

struct BetterDivider: View {

    @State var color: Color

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                path.move(to: .zero)
                path.addLine(to: CGPoint(x: geometry.size.width, y: 0))
            }
                .stroke(lineWidth: 0.33)
                .foregroundColor(color)
        }
            .padding(.all, 0)
            .frame(height: 0.33)
            .opacity(0.33)
    }
}
