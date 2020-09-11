// 
//  MarketDataView.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2020-09-09.
//  Copyright © 2020 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import SwiftUI

@available(iOS 13.0, *)
struct MarketDataView: View {
    
    private let strokeColor = Color.white.opacity(0.15)
    private let fillColor = Color.white.opacity(0.1)
    private let textColor = Color.white
    private let subTextColor = Color.white.opacity(0.69)
    private let textSize = 16.0
    
    @ObservedObject var marketData: MarketDataPublisher
    
    init(currencyId: String) {
        let fiatId = Store.state.defaultCurrencyCode.lowercased()
        marketData = MarketDataPublisher(currencyId: currencyId, fiatId: fiatId)
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .center) {
                text(marketData.viewModel.marketCap)
                subText(S.MarketData.marketCap)
                text(marketData.viewModel.totalVolume)
                subText(S.MarketData.volume)
            }.padding(8.0)
            .frame(minWidth: 0, maxWidth: .infinity)
            Rectangle()
                .fill(strokeColor)
                .frame(width: 1.0)
                .cornerRadius(0.5)
                .padding([.top, .bottom], 4.0)
            VStack(alignment: .center) {
                text(marketData.viewModel.high24h)
                subText(S.MarketData.high24h)
                text(marketData.viewModel.low24h)
                subText(S.MarketData.low24h)
            }.padding(8.0)
            .frame(minWidth: 0, maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .fixedSize(horizontal: false, vertical: true)
        .background(fillColor)
        .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(strokeColor, lineWidth: 1)
        ).onAppear(perform: {
            self.marketData.fetch()
        })
    }
    
    func text(_ text: String) -> Text {
        Text(text)
            .font(Font(Theme.body1))
            .foregroundColor(textColor)
    }
    
    func subText(_ text: String) -> Text {
        Text(text)
            .font(Font(Theme.caption))
            .foregroundColor(subTextColor)
    }
    
}

@available(iOS 13.0, *)
struct MarketDataView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.orange
                .edgesIgnoringSafeArea(.all)
            MarketDataView(currencyId: "bitcoin")
        }
    }
}
