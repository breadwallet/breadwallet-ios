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

    var descriptionString: NSAttributedString {
        let fontSize: CGFloat = 14.0

        let regularAttributes: [String: Any] = [
            NSFontAttributeName: UIFont.customBody(size: fontSize),
            NSForegroundColorAttributeName: UIColor.secondaryText
        ]

        let boldAttributes: [String: Any] = [
            NSFontAttributeName: UIFont.customBold(size: fontSize),
            NSForegroundColorAttributeName: UIColor.secondaryText
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
        if timestamp < 60 {
            return "\(timestamp) m"
        } else {
            return "\(timestamp/60) h"
        }
    }

    let direction: TransactionDirection
    let amount: UInt
    let status: String
    let comment: String
    let timestamp: UInt
}

extension Transaction {
    static var random: Transaction {
        return Transaction(direction: arc4random_uniform(2) == 0 ? .sent : .received,
                           amount: UInt(arc4random_uniform(100)),
                           status: arc4random_uniform(2) == 0 ? "Waiting" : "Complete",
                           comment: comments[Int(arc4random_uniform(UInt32(comments.count)))],
                           timestamp: UInt(arc4random_uniform(3000)))
    }
}
