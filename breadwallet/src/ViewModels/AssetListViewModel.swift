//
//  AssetListViewModel.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2018-01-31.
//  Copyright © 2018 breadwallet LLC. All rights reserved.
//

import Foundation

struct AssetListViewModel {
    let currency: Currency
    
    var exchangeRate: String {
        guard let rate = currency.state?.currentRate else { return "" }
        let placeholderAmount = Amount(amount: 0, currency: currency, rate: rate)
        guard let rateText = placeholderAmount.localFormat.string(from: NSNumber(value: rate.rate)) else { return "" }
        return String(format: S.AccountHeader.exchangeRate, rateText, currency.code)
    }
    
    var fiatBalance: String {
        guard let rate = currency.state?.currentRate else { return "" }
        return balanceString(inFiatWithRate: rate)
    }
    
    var tokenBalance: String {
        return balanceString()
    }
    
    /// Returns balance string in fiat if rate specified or token amount otherwise
    private func balanceString(inFiatWithRate rate: Rate? = nil) -> String {
        guard let balance = currency.state?.balance else { return "" }
        return Amount(amount: balance,
                      currency: currency,
                      rate: rate).description
    }
}
