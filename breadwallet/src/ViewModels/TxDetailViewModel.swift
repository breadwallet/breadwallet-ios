//
//  TxDetailViewModel.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-12-20.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit
import BRCore

/// View model of a transaction in detail view
struct TxDetailViewModel: TxViewModel {
    
    // MARK: -
    
    let amount: String
    let fiatAmount: String
    let originalFiatAmount: String?
    let exchangeRate: String?
    let transactionHash: String
    let tx: Transaction
    
    // Ethereum-specific fields
    var gasPrice: String?
    var gasLimit: String?
    var fee: String?
    var total: String?
    
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
    
    var timestampHeader: NSAttributedString {
        if status == .complete {
            let text = " " + S.TransactionDetails.completeTimestampHeader
            let attributedString = NSMutableAttributedString(string: text)
            let icon = NSTextAttachment()
            icon.image = #imageLiteral(resourceName: "CircleCheckSolid").withRenderingMode(.alwaysTemplate)
            icon.bounds = CGRect(x: 0, y: -2.0, width: 14.0, height: 14.0)
            let iconString = NSMutableAttributedString(string: S.Symbols.narrowSpace) // space required before an attachment to apply template color (UIKit bug)
            iconString.append(NSAttributedString(attachment: icon))
            attributedString.insert(iconString, at: 0)
            attributedString.addAttributes([.foregroundColor: UIColor.receivedGreen,
                                            .font: UIFont.customBody(size: 0.0)],
                                           range: NSMakeRange(0, iconString.length))
            return attributedString
        } else {
            return NSAttributedString(string: S.TransactionDetails.initializedTimestampHeader)
        }
    }
    
    var addressHeader: String {
        if direction == .sent {
            return S.TransactionDetails.addressToHeader
        } else {
            if tx is BtcTransaction {
                return S.TransactionDetails.addressViaHeader
            } else {
                return S.TransactionDetails.addressFromHeader
            }
        }
    }
}

extension TxDetailViewModel {
    init(tx: Transaction) {
        let rate = tx.currency.state?.currentRate ?? Rate.empty
        amount = TxDetailViewModel.tokenAmount(tx: tx) ?? ""
        
        let fiatAmounts = TxDetailViewModel.fiatAmounts(tx: tx, currentRate: rate)
        fiatAmount = fiatAmounts.0
        originalFiatAmount = fiatAmounts.1
        exchangeRate = TxDetailViewModel.exchangeRateText(tx: tx)
        transactionHash = tx.hash
        self.tx = tx
        
        if let tx = tx as? EthLikeTransaction {
            let gasFormatter = NumberFormatter()
            gasFormatter.numberStyle = .decimal
            gasFormatter.maximumFractionDigits = 0
            gasLimit = (currency is ERC20Token) ? nil : gasFormatter.string(from: tx.gasLimit as NSNumber)
            
            let feeCurrency = (currency is ERC20Token) ? Currencies.eth : currency
            
            gasPrice = Amount(amount: tx.gasPrice, currency: feeCurrency, rate: rate).tokenDescription(inUnit: Ethereum.Units.gwei)
            
            let totalFee = tx.gasPrice * UInt256(tx.gasUsed)
            let feeAmount = Amount(amount: totalFee, currency: feeCurrency, rate: rate, maximumFractionDigits: Amount.highPrecisionDigits)
            
            // gas used is unknown until confirmed
            if tx.direction == .sent && tx.confirmations > 0 {
                // omit total for ERC20
                let totalAmount: Amount? = (currency is ERC20Token) ? nil : Amount(amount: tx.amount + totalFee, currency: tx.currency, rate: rate, maximumFractionDigits: Amount.highPrecisionDigits)
                
                if Store.state.isBtcSwapped {
                    fee = feeAmount.fiatDescription
                    total = totalAmount?.fiatDescription
                } else {
                    fee = feeAmount.tokenDescription
                    total = totalAmount?.tokenDescription
                }
            }
        }
        
        if let tx = tx as? BtcTransaction, tx.direction == .sent {
            let feeAmount = Amount(amount: UInt256(tx.fee), currency: tx.currency, rate: rate, maximumFractionDigits: Amount.highPrecisionDigits)
            fee = Store.state.isBtcSwapped ? feeAmount.fiatDescription : feeAmount.tokenDescription
        }
    }
    
    /// The fiat exchange rate at the time of transaction
    /// Assumes fiat currency does not change
    private static func exchangeRateText(tx: Transaction) -> String? {
        guard let rate = tx.metaData?.exchangeRate,
            let symbol = tx.currency.state?.currentRate?.currencySymbol else { return nil }
        
        let nf = NumberFormatter()
        nf.currencySymbol = symbol
        nf.numberStyle = .currency
        return nf.string(from: rate as NSNumber) ?? nil
    }
    
    private static func tokenAmount(tx: Transaction) -> String? {
        let amount = Amount(amount: tx.amount,
                            currency: tx.currency,
                            rate: nil,
                            maximumFractionDigits: Amount.highPrecisionDigits,
                            negative: (tx.direction == .sent))
        return amount.description
    }
    
    /// Fiat amount at current exchange rate and at original rate at time of transaction (if available)
    /// Returns (currentFiatAmount, originalFiatAmount)
    private static func fiatAmounts(tx: Transaction, currentRate: Rate) -> (String, String?) {
        if let txRate = tx.metaData?.exchangeRate {
            let originalRate = Rate(code: currentRate.code,
                                    name: currentRate.name,
                                    rate: txRate,
                                    reciprocalCode: currentRate.reciprocalCode)
            let currentAmount = Amount(amount: tx.amount,
                                       currency: tx.currency,
                                       rate: currentRate,
                                       negative: false).description
            let originalAmount = Amount(amount: tx.amount,
                                        currency: tx.currency,
                                        rate: originalRate,
                                        negative: false).description
            return (currentAmount, originalAmount)
        } else {
            // no tx-time rate
            let currentAmount = Amount(amount: tx.amount,
                                       currency: tx.currency,
                                       rate: currentRate,
                                       negative: false)
            return (currentAmount.description, nil)
        }
    }
}
