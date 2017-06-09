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
    case moved = "Moved"

    var amountFormat: String {
        switch self {
        case .sent:
            return S.TransactionDetails.sent
        case .received:
            return S.TransactionDetails.received
        case .moved:
            return S.TransactionDetails.moved
        }
    }

    var sign: String {
        switch self {
        case .sent:
            return "-"
        case .received:
            return ""
        case .moved:
            return ""
        }
    }

    var addressHeader: String {
        switch self {
        case .sent:
            return S.TransactionDirection.to
        case .received:
            return S.TransactionDirection.received
        case .moved:
            return S.TransactionDirection.to
        }
    }

    var descriptionFormat: String {
        switch self {
        case .sent:
            return S.TransactionDetails.sendDescription
        case .received:
            return S.TransactionDetails.receivedDescription
        case .moved:
            return S.TransactionDetails.movedDescription
        }
    }

    var addressText: String {
        switch self {
        case .sent:
            return S.TransactionDetails.to
        case .received:
            return S.TransactionDetails.from
        case .moved:
            return S.TransactionDetails.to
        }
    }
}
