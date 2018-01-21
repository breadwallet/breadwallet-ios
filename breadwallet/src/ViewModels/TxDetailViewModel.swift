//
//  TxDetailViewModel.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-12-20.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation

/// View model of a transaction in detail view
struct TxDetailViewModel: TxViewModel {
    
    // MARK: -
    
    let amount: String
    let fiatAmount: String
    let startingBalance: String
    let endingBalance: String
    let exchangeRate: String
    let transactionHash: String
    let tx: Transaction
}

extension TxDetailViewModel {
    init(tx: Transaction) {
        amount = TxDetailViewModel.amountDescription(tx: tx, isBtcSwapped: false)
        fiatAmount = TxDetailViewModel.amountDescription(tx: tx, isBtcSwapped: true)
        
        // TODO:ER update balances when isBtcSwapped switches
        let balances = TxDetailViewModel.balances(tx: tx, isBtcSwapped: Store.state.isBtcSwapped)
        
        startingBalance = balances.0
        endingBalance = balances.1
        exchangeRate = TxDetailViewModel.exchangeRate(tx: tx, rates: Store.state.rates) ?? ""
        transactionHash = tx.hash
        self.tx = tx
    }
    
    private static func amountDescription(tx: Transaction, isBtcSwapped: Bool) -> String {
        guard let rate = Store.state.currentRate else { return  "" }
        let maxDigits = Store.state.maxDigits
        
        if let tx = tx as? EthTransaction {
            if isBtcSwapped {
                return DisplayAmount.localEthString(value: tx.amount)
            } else {
                return DisplayAmount.ethString(value: tx.amount)
            }
        } else if let tx = tx as? BtcTransaction {
            let amount = Amount(amount: tx.amount, rate: rate, maxDigits: maxDigits, currency: Currencies.btc)
            return isBtcSwapped ? amount.localCurrency : amount.bits
        } else {
            return ""
        }
    }
    
    private static func balances(tx: Transaction, isBtcSwapped: Bool) -> (String, String) {
        guard let tx = tx as? BtcTransaction,
            let rate = Store.state.currentRate else { return ("", "") }
        let maxDigits = Store.state.maxDigits
        
        var startingString = Amount(amount: tx.startingBalance,
                                    rate: rate,
                                    maxDigits: maxDigits,
                                    currency: Currencies.btc).string(isBtcSwapped: isBtcSwapped)
        var endingString = Amount(amount: tx.endingBalance,
                                  rate: rate,
                                  maxDigits: maxDigits,
                                  currency: Currencies.btc).string(isBtcSwapped: isBtcSwapped)
        
        if tx.startingBalance > C.maxMoney {
            startingString = ""
            endingString = ""
        }
        
        return (startingString, endingString)
    }
    
    private static func exchangeRate(tx: Transaction, rates: [Rate]) -> String? {
        guard let tx = tx as? BtcTransaction else { return nil }
        
        var exchangeRateInfo = ""
        if let metaData = tx.metaData,
            let currentRate = rates.filter({ $0.code.lowercased() == metaData.exchangeRateCurrency.lowercased() }).first {
            let difference = (currentRate.rate - metaData.exchangeRate) / metaData.exchangeRate
            
            let nf = NumberFormatter()
            nf.currencySymbol = currentRate.currencySymbol
            nf.numberStyle = .currency
            
            let diffFormat = NumberFormatter()
            diffFormat.positivePrefix = "+"
            diffFormat.numberStyle = .percent
            diffFormat.minimumFractionDigits = 1
            
            if let rateString = nf.string(from: metaData.exchangeRate as NSNumber),
                let diffString = diffFormat.string(from: difference as NSNumber) {
                exchangeRateInfo = "\(rateString)/\(tx.currency.code) \(diffString)"
            }
        }
        
        return exchangeRateInfo
    }
}
