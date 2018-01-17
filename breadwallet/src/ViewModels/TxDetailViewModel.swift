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
    init(tx: Transaction, store: Store) {
        amount = TxDetailViewModel.amountDescription(tx: tx, isBtcSwapped: false, store: store)
        fiatAmount = TxDetailViewModel.amountDescription(tx: tx, isBtcSwapped: true, store: store)
        
        // TODO:ER update balances when isBtcSwapped switches
        let balances = TxDetailViewModel.balances(tx: tx, isBtcSwapped: store.state.isBtcSwapped, store: store)
        
        startingBalance = balances.0
        endingBalance = balances.1
        exchangeRate = TxDetailViewModel.exchangeRate(tx: tx, rates: store.state.rates) ?? ""
        transactionHash = tx.hash
        self.tx = tx
    }
    
    private static func amountDescription(tx: Transaction, isBtcSwapped: Bool, store: Store) -> String {
        guard let rate = store.state.currentRate else { return  "" }
        let maxDigits = store.state.maxDigits
        
        if let tx = tx as? EthTransaction {
            if isBtcSwapped {
                return DisplayAmount.localEthString(value: tx.amount, store: store)
            } else {
                return DisplayAmount.ethString(value: tx.amount, store: store)
            }
        } else if let tx = tx as? BtcTransaction {
            let amount = Amount(amount: tx.amount, rate: rate, maxDigits: maxDigits, store: store)
            return isBtcSwapped ? amount.localCurrency : amount.bits
        } else {
            return ""
        }
    }
    
    private static func balances(tx: Transaction, isBtcSwapped: Bool, store: Store) -> (String, String) {
        guard let tx = tx as? BtcTransaction,
            let rate = store.state.currentRate else { return ("", "") }
        let maxDigits = store.state.maxDigits
        
        var startingString = Amount(amount: tx.startingBalance,
                                    rate: rate,
                                    maxDigits: maxDigits,
                                    store: store).string(isBtcSwapped: isBtcSwapped)
        var endingString = Amount(amount: tx.endingBalance,
                                  rate: rate,
                                  maxDigits: maxDigits,
                                  store: store).string(isBtcSwapped: isBtcSwapped)
        
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
