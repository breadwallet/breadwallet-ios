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
  
  class func simplexRanges() -> String {
    
    if let code  = Locale.current.currencyCode, let symbol = Currency.getSymbolForCurrencyCode(code: code), let range = Currency.simplexDailyLimits()[code] {
      switch code {
      case "USD":
        return "\n• Swap" + " \(symbol)\(range[0])~\(symbol)\(range[1])" + " + fees daily"
      case "EUR":
        return "\n• Swap" + " \(range[0])\(symbol)~\(range[1])\(symbol)" + " + fees daily"
      default:
        return "\n• Swap" + " \(symbol)\(range[0])~\(symbol)\(range[1])" + " + fees daily"
      }
    }
    return "\n• Swap $40~$18,500 + fees daily"
  }
}
