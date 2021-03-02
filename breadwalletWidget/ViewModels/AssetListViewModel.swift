//
//  AssetViewModel.swift
//  ChartDemo
//
//  Created by stringcode on 15/02/2021.
//  Copyright © 2021 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import Foundation
import SwiftUI

struct AssetListViewModel {

    let assets: [AssetViewModel]

    var anyAsset: AssetViewModel {
        return assets.first ?? AssetListViewModel.mock().assets[0]
    }
    
    init(assets: [AssetViewModel]) {
        self.assets = assets
    }
    
    init(config: Configuration,
         currencies: [Currency],
         info: [CurrencyId: MarketInfo],
         availableCurrencies: [Currency]) {
        assets = currencies.map {
            .init(config: config,
                  currency: $0,
                  info: info[$0.uid],
                  currencies: availableCurrencies)
        }
    }
}

// MARK: - Mock

extension AssetListViewModel {

    static func mock(_ cnt: Int = 3) -> AssetListViewModel {
        let assets = [AssetViewModel.mock(.btc),
                      AssetViewModel.mock(.eth),
                      AssetViewModel.mock(.brd)]
        return .init(assets: Array(assets[0..<cnt]))
    }

}
