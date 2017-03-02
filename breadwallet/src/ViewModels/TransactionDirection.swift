//
//  TransactionDirection.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-03-01.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation

enum TransactionDirection : String {
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

    var sign: String {
        switch self {
        case .sent:
            return "-"
        case .received:
            return ""
        }
    }
}
