//
//  Transaction.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-11-17.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import Foundation

let comments = ["Gift Cards", "🍜", "Dinner and drinks", "", "All the mods 😵🙌", "This is a multiline comment used for testing if the cell will resize with longer comments like this"]

enum TransactionDirection {
    case sent
    case received
}

struct Transaction {

    var descriptionString: String {
        switch direction {
            case .sent:
                return "Sent \(amount) to account"
            case .received:
                return "Received \(amount) from account"
        }
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
