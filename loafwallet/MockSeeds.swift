//
//  MockSeeds.swift
//  loafwallet
//
//  Created by Kerry Washington on 12/15/19.
//  Copyright © 2019 Litecoin Foundation. All rights reserved.
//

import Foundation

//Draft list of mock data to inject into tests
struct MockSeeds {
      static let date100 = Date(timeIntervalSince1970: 1000)
      static let rate100 = Rate(code: "USD", name: "US Dollar", rate: 43.3833, lastTimestamp: date100)
      static let amount100 = Amount(amount: 100, rate: rate100, maxDigits: 4443588634)
 }
