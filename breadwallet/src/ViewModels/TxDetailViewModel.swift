//
//  TxDetailViewModel.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-12-20.
//  Copyright © 2017-2019 Breadwinner AG. All rights reserved.
//

import UIKit

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
        case .recovered:
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
                                           range: NSRange(location: 0, length: iconString.length))
            return attributedString
        } else {
            return NSAttributedString(string: S.TransactionDetails.initializedTimestampHeader)
        }
    }
    
    var addressHeader: String {
        if direction == .sent {
            return S.TransactionDetails.addressToHeader
        } else {
            if tx.currency.isBitcoinCompatible {
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

        if tx.direction == .sent {
            var feeAmount = tx.fee
            feeAmount.maximumFractionDigits = Amount.highPrecisionDigits
            fee = Store.state.showFiatAmounts ? feeAmount.fiatDescription : feeAmount.tokenDescription
        }

        //TODO:CRYPTO incoming token transfers have a feeBasis with 0 values
        if let feeBasis = tx.feeBasis,
            (currency.isEthereum || (currency.isEthereumCompatible && tx.direction == .sent)) {
            let gasFormatter = NumberFormatter()
            gasFormatter.numberStyle = .decimal
            gasFormatter.maximumFractionDigits = 0
            self.gasLimit = gasFormatter.string(from: feeBasis.costFactor as NSNumber)

            let gasUnit = feeBasis.pricePerCostFactor.currency.unit(named: "gwei") ?? currency.defaultUnit
            gasPrice = feeBasis.pricePerCostFactor.tokenDescription(in: gasUnit)
        }

        // for outgoing txns for native tokens show the total amount sent including fee
        if tx.direction == .sent, tx.confirmations > 0, tx.amount.currency == tx.fee.currency {
            var totalWithFee = tx.amount + tx.fee
            totalWithFee.maximumFractionDigits = Amount.highPrecisionDigits
            total = Store.state.showFiatAmounts ? totalWithFee.fiatDescription : totalWithFee.tokenDescription
        }
    }
    
    /// The fiat exchange rate at the time of transaction
    /// Returns nil if no rate found or rate currency mismatches the current fiat currency
    private static func exchangeRateText(tx: Transaction) -> String? {
        guard let metaData = tx.metaData,
            let currentRate = tx.currency.state?.currentRate,
            !metaData.exchangeRate.isZero,
            (metaData.exchangeRateCurrency == currentRate.code || metaData.exchangeRateCurrency.isEmpty) else { return nil }
        let nf = NumberFormatter()
        nf.currencySymbol = currentRate.currencySymbol
        nf.numberStyle = .currency
        return nf.string(from: metaData.exchangeRate as NSNumber) ?? nil
    }
    
    private static func tokenAmount(tx: Transaction) -> String? {
        let amount = Amount(amount: tx.amount,
                            rate: nil,
                            maximumFractionDigits: Amount.highPrecisionDigits,
                            negative: (tx.direction == .sent && !tx.amount.isZero))
        return amount.description
    }
    
    /// Fiat amount at current exchange rate and at original rate at time of transaction (if available)
    /// Returns the token transfer description for token transfer originating transactions, as first return value.
    /// Returns (currentFiatAmount, originalFiatAmount)
    private static func fiatAmounts(tx: Transaction, currentRate: Rate) -> (String, String?) {
        let currentAmount = Amount(amount: tx.amount,
                                   rate: currentRate).description
        
        guard let metaData = tx.metaData else { return (currentAmount, nil) }
        
        guard metaData.tokenTransfer.isEmpty else {
            let tokenTransfer = String(format: S.Transaction.tokenTransfer, metaData.tokenTransfer.uppercased())
            return (tokenTransfer, nil)
        }
        
        // no tx-time rate
        guard !metaData.exchangeRate.isZero,
            (metaData.exchangeRateCurrency == currentRate.code || metaData.exchangeRateCurrency.isEmpty) else {
                return (currentAmount, nil)
        }
        
        let originalRate = Rate(code: currentRate.code,
                                name: currentRate.name,
                                rate: metaData.exchangeRate,
                                reciprocalCode: currentRate.reciprocalCode)
        let originalAmount = Amount(amount: tx.amount,
                                    rate: originalRate).description
        return (currentAmount, originalAmount)
    }
}
