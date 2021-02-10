// 
//  MarketDataPublisher.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2020-09-09.
//  Copyright © 2020 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//
import Foundation
import Combine
import CoinGecko

struct MarketDataViewModel {
    let data: MarketContainer?
    
    var marketCap: String { format(value: data?.marketCap, decimals: 0) }
    var totalVolume: String { format(value: data?.totalVolume, decimals: 0) }
    var high24h: String { format(value: data?.high24h, decimals: 2) }
    var low24h: String { format(value: data?.low24h, decimals: 2) }
    
    private func format(value: Double?, decimals: Int) -> String {
        guard let val = value else { return " " }
        return formatter(decimals: decimals).string(from: NSNumber(value: val)) ?? " "
    }
    
    private func formatter(decimals: Int) -> NumberFormatter {
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.minimumFractionDigits = decimals
        nf.maximumFractionDigits = decimals
        nf.currencySymbol = Rate.symbolMap[Store.state.defaultCurrencyCode]
        return nf
    }
    
}

@available(iOS 13.0, *)
class MarketDataPublisher: ObservableObject {
    
    @Published var viewModel = MarketDataViewModel(data: nil)
    
    let currencyId: String
    let fiatId: String
    
    init(currencyId: String, fiatId: String) {
        self.currencyId = currencyId
        self.fiatId = fiatId
    }
    
    private let client = CoinGeckoClient()
    
    func fetch() {
        let resource = Resources.coin(currencyId: currencyId, vs: fiatId) { (result: Result<MarketContainer, CoinGeckoError>) in
            guard case .success(let data) = result else { return }
            DispatchQueue.main.async {
                self.viewModel = MarketDataViewModel(data: data)
            }
        }
        client.load(resource)
    }
    
}
