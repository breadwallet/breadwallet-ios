//
//  Transaction.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-11-17.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

let comments = ["Gift Cards", "🍜", "Dinner and drinks", "", "All the mods 😵🙌", "This is a multiline comment used for testing if the cell will resize with longer comments like this"]

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

    init(amountSent: UInt64, amountReceived: UInt64, timestamp: UInt32, transactionIsValid: Bool, transactionIsPending: Bool, transactionIsVerified: Bool, blockHeight: UInt32, transactionBlockHeight: UInt32) {
        if amountSent > 0 && amountSent == amountReceived {
            self.direction = .sent
        } else {
            self.direction = .received
        }
        self.status = "Complete"
        self.comment = comments[Int(arc4random_uniform(UInt32(comments.count)))]
        self.amount = self.direction == .sent ? amountSent : amountReceived
        self.timestamp = Int(timestamp)

        //confirms = ($0.pointee.blockHeight > blockHeight) ? 0 : (blockHeight - $0.pointee.blockHeight) + 1
    }

    var descriptionString: NSAttributedString {
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

        let amountString = NSMutableAttributedString(string: "$\(amount) ")
        amountString.addAttributes(boldAttributes, range: NSRange(location: 0, length: amountString.length))

        let preposition = NSMutableAttributedString(string: "\(direction.preposition) ")
        preposition.addAttributes(regularAttributes, range: NSRange(location: 0, length: preposition.length))

        let suffix = NSMutableAttributedString(string: "account")
        suffix.addAttributes(boldAttributes, range: NSRange(location: 0, length: suffix.length))

        prefix.append(amountString)
        prefix.append(preposition)
        prefix.append(suffix)

        return prefix
    }

    var timestampString: String {
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

    let direction: TransactionDirection
    let amount: UInt64
    let status: String
    let comment: String
    let timestamp: Int
}
