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
    let originalFiatAmount: String?
    let startingBalance: String
    let endingBalance: String
    let exchangeRate: String
    let transactionHash: String
    let tx: Transaction
    
    var title: String {
        guard status != .invalid else { return S.TransactionDetails.titleFailed }
        switch direction {
        case .moved:
            return S.TransactionDetails.titleInternal
        case .received:
            return status == .complete ? S.TransactionDetails.titleReceived : S.TransactionDetails.titleReceiving
        case .sent:
            return status == .complete ? S.TransactionDetails.titleSent : S.TransactionDetails.titleSending
        }
    }
}

extension TxDetailViewModel {
    init(tx: Transaction) {
        let rate = Store.state[tx.currency]?.currentRate ?? Rate.empty
        amount = TxDetailViewModel.tokenAmount(tx: tx) ?? ""
        
        let fiatAmounts = TxDetailViewModel.fiatAmounts(tx: tx, currentRate: rate)
        fiatAmount = fiatAmounts.0
        originalFiatAmount = fiatAmounts.1
        
        let balances = TxDetailViewModel.balances(tx: tx, showFiatAmount: Store.state.isBtcSwapped)
        
        startingBalance = balances.0
        endingBalance = balances.1
        exchangeRate = TxDetailViewModel.exchangeRateText(tx: tx) ?? ""
        transactionHash = tx.hash
        self.tx = tx
    }
    
    private static func balances(tx: Transaction, showFiatAmount: Bool) -> (String, String) {
        guard let tx = tx as? BtcTransaction,
            let rate = Store.state[tx.currency]?.currentRate else { return ("", "") }
        let maxDigits = Store.state.maxDigits
        
        var startingString = Amount(amount: tx.startingBalance,
                                    rate: rate,
                                    maxDigits: maxDigits,
                                    currency: Currencies.btc).string(isBtcSwapped: showFiatAmount)
        var endingString = Amount(amount: tx.endingBalance,
                                  rate: rate,
                                  maxDigits: maxDigits,
                                  currency: Currencies.btc).string(isBtcSwapped: showFiatAmount)
        
        if tx.startingBalance > C.maxMoney {
            startingString = ""
            endingString = ""
        }
        
        return (startingString, endingString)
    }
    
    /// The fiat exchange rate at the time of transaction
    /// Assumes fiat currency does not change
    private static func exchangeRateText(tx: Transaction) -> String? {
        guard let tx = tx as? BtcTransaction,
            let rate = tx.metaData?.exchangeRate else { return nil }
        
        let nf = NumberFormatter()
        nf.currencySymbol = tx.currency.symbol // TODO: this should be the fiat symbol, where do I get that?
        nf.numberStyle = .currency
        return nf.string(from: rate as NSNumber) ?? nil
    }
    
    private static func tokenAmount(tx: Transaction) -> String? {
        guard let tx = tx as? BtcTransaction else { return nil }
        let amount = DisplayAmount(amount: Satoshis(rawValue: tx.amount),
                                   selectedRate: nil,
                                   minimumFractionDigits: nil,
                                   currency: tx.currency)
        return amount.description
    }
    
    /// Fiat amount at current exchange rate and at original rate at time of transaction (if available)
    /// Returns (currentFiatAmount, originalFiatAmount)
    private static func fiatAmounts(tx: Transaction, currentRate: Rate) -> (String, String?) {
        guard let tx = tx as? BtcTransaction else { return ("", nil) }
        if let txRate = tx.metaData?.exchangeRate {
            let originalRate = Rate(code: currentRate.code,
                                    name: currentRate.name,
                                    rate: txRate,
                                    reciprocalCode: currentRate.reciprocalCode)
            let currentAmount = DisplayAmount(amount: Satoshis(rawValue: tx.amount),
                                              selectedRate: currentRate,
                                              minimumFractionDigits: nil,
                                              currency: tx.currency).description
            let originalAmount = DisplayAmount(amount: Satoshis(rawValue: tx.amount),
                                               selectedRate: originalRate,
                                               minimumFractionDigits: nil,
                                               currency: tx.currency).description
            return (currentAmount, originalAmount)
            
        } else {
            // no tx-time rate
            let currentAmount = DisplayAmount(amount: Satoshis(rawValue: tx.amount),
                                              selectedRate: currentRate,
                                              minimumFractionDigits: nil,
                                              currency: tx.currency)
            return (currentAmount.description, nil)
        }
    }
}
