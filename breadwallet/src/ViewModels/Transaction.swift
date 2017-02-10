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

    init(amountSent: UInt64, amountReceived: UInt64, timestamp: UInt32, transactionIsValid: Bool, transactionIsPending: Bool, transactionIsVerified: Bool, blockHeight: UInt32, transactionBlockHeight: UInt32, fee: UInt64) {


        //TODO - use real rates here
        if amountSent > 0 {
            self.direction = .sent
            self.amount = Amount(amount: amountSent - amountReceived - fee, rate: 920.0)
        } else {
            self.direction = .received
            self.amount = Amount(amount:amountReceived - fee, rate: 920.0)
        }
        self.timestamp = Int(timestamp)
        let confirms = transactionBlockHeight > blockHeight ? 0 : Int((blockHeight - transactionBlockHeight) + 1)
        self.status = makeStatus(isValid: transactionIsValid, isPending: transactionIsPending, isVerified: transactionIsVerified, confirms: confirms)
        self.comment = ""
    }

    let direction: TransactionDirection
    let amount: Amount
    let status: String
    let comment: String
    let timestamp: Int

    func descriptionString(currency: Currency) -> NSAttributedString {
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
    return lhs.direction == rhs.direction && lhs.amount.bits == rhs.amount.bits && lhs.amount.localCurrency == rhs.amount.localCurrency && lhs.comment == rhs.comment && lhs.timestamp == rhs.timestamp
}
