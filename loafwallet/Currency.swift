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
   
  class func returnSimplexSupportedFiat(givenCode:String) -> String {
    if (givenCode == "USD" || givenCode == "EUR") {
      return givenCode
    }
    return "USD"
  }
    
}

enum PartnerFiatOptions: Int, CustomStringConvertible {
    case cad
    case eur
    case jpy
    case usd
    
    public var description: String {
        return code
    }
     
    private var code: String {
        switch self {
        case .cad: return "CAD"
        case .eur: return "EUR"
        case .jpy: return "JPY"
        case .usd: return "USD"
        }
    }
    
    public var index: Int {
        switch self {
        case .cad: return 0
        case .eur: return 1
        case .jpy: return 2
        case .usd: return 3
        }
    }
}
