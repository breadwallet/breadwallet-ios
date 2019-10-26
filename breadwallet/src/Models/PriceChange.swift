//
//  FiatPriceInfo.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2019-06-03.
//  Copyright © 2019 breadwallet LLC. All rights reserved.
//

import Foundation

struct FiatPriceInfo: Equatable {
    let changePercentage24Hrs: Double
    let change24Hrs: Double
    let price: Double
}
