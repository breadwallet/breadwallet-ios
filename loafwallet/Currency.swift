//
//  Currency.swift
//  breadwallet
//
//  Created by Kerry Washington on 10/2/18.
//  Copyright © 2018 breadwallet LLC. All rights reserved.
//

import Foundation
import UIKit

class Currency {

  class func simplexDailyLimits() -> [String:[String]] {
    return ["EUR":["40","16.000"],"USD":["40","18,500"]]
  }
  
  class func getSymbolForCurrencyCode(code: String) -> String? {
    let result = Locale.availableIdentifiers.map { Locale(identifier: $0) }.first { $0.currencyCode == code }
    return result?.currencySymbol
  }
   
  class func checkSimplexFiatSupport(givenCode:String) -> String? {
    if (givenCode == "USD" || givenCode == "EUR") {
      return givenCode
    }
    return "USD"
  }
    
}
