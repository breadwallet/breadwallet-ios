//
//  Transaction.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-11-17.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

enum TransactionDirection: String {
    case sent = "Sent"
    case received = "Received"

    var preposition: String {
        switch self {
        case .sent:
            return "to"
        case .received:
            return "from"
        }
    }
}

struct Transaction {

    init(_ tx: BRTxRef, wallet: BRWallet, blockHeight: UInt32) {
        self.tx = tx
        self.wallet = wallet

        self.fee = wallet.feeForTx(tx) ?? 0
        let amountReceived = wallet.amountReceivedFromTx(tx)

        //TODO - use real rates here
        if wallet.amountSentByTx(tx) > 0 {
            self.direction = .sent
            self.satoshis = wallet.amountSentByTx(tx) - amountReceived - fee
        } else {
            self.direction = .received
            self.satoshis = amountReceived - fee
        }
        self.timestamp = Int(tx.pointee.timestamp)

        let transactionBlockHeight = tx.pointee.blockHeight
        let transactionIsValid = wallet.transactionIsValid(tx)
        let transactionIsVerified = wallet.transactionIsVerified(tx)
        let transactionIsPending = wallet.transactionIsPending(tx)

        let confirms = transactionBlockHeight > blockHeight ? 0 : Int((blockHeight - transactionBlockHeight) + 1)
        self.status = makeStatus(isValid: transactionIsValid, isPending: transactionIsPending, isVerified: transactionIsVerified, confirms: confirms)
        self.comment = ""
        self.longStatus = confirms > 6 ? "Complete" : "Waiting to be confirmed. Some merchants require confirmation to complete a transaction. Estimated time: 1-2 hours."

        self.balanceAfter = wallet.balanceAfterTx(tx)
    }

    let tx: BRTxRef
    let wallet: BRWallet


    let direction: TransactionDirection
    let satoshis: UInt64
    let status: String
    let longStatus: String
    let comment: String
    let timestamp: Int
    let balanceAfter: UInt64 //TODO - make me lazy
    let fee: UInt64

    func amountDescription(currency: Currency, rate: Rate) -> String {
        let amount = Amount(amount: satoshis, rate: rate.rate)
        return currency == .bitcoin ? amount.bits : amount.localCurrency
    }

    func descriptionString(currency: Currency, rate: Rate) -> NSAttributedString {

        let amount = Amount(amount: satoshis, rate: rate.rate)
        let fontSize: CGFloat = 14.0

        let regularAttributes: [String: Any] = [
            NSFontAttributeName: UIFont.customBody(size: fontSize),
            NSForegroundColorAttributeName: UIColor.darkText
        ]

        let boldAttributes: [String: Any] = [
            NSFontAttributeName: UIFont.customBold(size: fontSize),
            NSForegroundColorAttributeName: UIColor.darkText
        ]

        let prefix = NSMutableAttributedString(string: "\(direction.rawValue) ")
        prefix.addAttributes(regularAttributes, range: NSRange(location: 0, length: prefix.length))

        let amountString = currency == .bitcoin ? amount.bits : amount.localCurrency
        let amountAttributedString = NSMutableAttributedString(string: amountString)
        amountAttributedString.addAttributes(boldAttributes, range: NSRange(location: 0, length: amountAttributedString.length))

        let preposition = NSMutableAttributedString(string: " \(direction.preposition) ")
        preposition.addAttributes(regularAttributes, range: NSRange(location: 0, length: preposition.length))

        let suffix = NSMutableAttributedString(string: "account")
        suffix.addAttributes(boldAttributes, range: NSRange(location: 0, length: suffix.length))

        prefix.append(amountAttributedString)
        prefix.append(preposition)
        prefix.append(suffix)

        return prefix
    }

    func amountDetails(currency: Currency, rate: Rate) -> String {
        let amount = Amount(amount: satoshis, rate: rate.rate)
        let amountString = currency == .bitcoin ? amount.bits : amount.localCurrency

        let endingAmount = Amount(amount: balanceAfter, rate: rate.rate)
        let endingAmountString = currency == .bitcoin ? endingAmount.bits : endingAmount.localCurrency

        var startingBalance: UInt64 = 0
        switch direction {
        case .received:
            startingBalance = balanceAfter - satoshis - fee
        case .sent:
            startingBalance = balanceAfter + satoshis + fee
        }
        let startingAmount = Amount(amount: startingBalance, rate: rate.rate)
        let startingAmountString = currency == .bitcoin ? startingAmount.bits : startingAmount.localCurrency
        return "\(amountString)\n\nStarting balance: \(startingAmountString)\nEnding balance: \(endingAmountString)"
    }

    var timeSince: String {
        guard timestamp > 0 else { return "just now" }
        let difference = Int(Date().timeIntervalSince1970) - timestamp
        let secondsInMinute = 60
        let secondsInHour = 3600
        let secondsInDay = 86400
        if (difference < secondsInMinute) {
            return "\(difference) s"
        } else if difference < secondsInHour {
            return "\(difference/secondsInMinute) m"
        } else if difference < secondsInDay {
            return "\(difference/secondsInHour) h"
        } else {
            return "\(difference/secondsInDay) d"
        }
    }

    var longTimestamp: String {
        let date = Date(timeIntervalSince1970: Double(timestamp))
        return longDateFormatter.string(from: date)
    }

    private let longDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "MMMM d, yyy 'at' h:mm a"
        return df
    }()
}

private func makeStatus(isValid: Bool, isPending: Bool, isVerified: Bool, confirms: Int) -> String {
    if confirms == 0 && !isValid {
        return "INVALID"
    } else if confirms == 0 && isPending {
        return "Pending"
    } else if confirms == 0 && !isVerified {
        return "Unverified"
    } else if confirms < 6 {
        if confirms == 0 {
            return "0 confirmations"
        } else if confirms == 1 {
            return "1 confirmation"
        } else {
            return "\(confirms) confirmations"
        }
    } else {
        return "Complete"
    }
}

extension Transaction : Equatable {}

func ==(lhs: Transaction, rhs: Transaction) -> Bool {
    return lhs.direction == rhs.direction && lhs.satoshis == rhs.satoshis && lhs.comment == rhs.comment && lhs.timestamp == rhs.timestamp
}
