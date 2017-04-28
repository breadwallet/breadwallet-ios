//
//  WatchTransaction.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-04-27.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation

enum WatchTransactionType : Int32 {
    case sent = 0
    case receive
    case move
    case invalid
}

private enum Keys {
    static let amount = "AW_TRANSACTION_DATA_AMOUNT_KEY"
    static let localAmount = "AW_TRANSACTION_DATA_AMOUNT_IN_LOCAL_CURRENCY_KEY"
    static let date = "AW_TRANSACTION_DATA_DATE_KEY"
    static let type = "AW_TRANSACTION_DATA_TYPE_KEY"
}

class WatchTransaction : NSObject, NSCoding {
    let amount: String
    let localAmount: String
    let date: String
    let type: WatchTransactionType

    required init(coder: NSCoder) {
        amount = coder.decodeObject(forKey: Keys.amount) as! String
        localAmount = coder.decodeObject(forKey: Keys.localAmount) as! String
        date = coder.decodeObject(forKey: Keys.date) as! String
        type = WatchTransactionType(rawValue: coder.decodeInt32(forKey: Keys.type))!
    }

    func encode(with aCoder: NSCoder) {
        aCoder.encode(amount, forKey: Keys.amount)
        aCoder.encode(localAmount, forKey: Keys.localAmount)
        aCoder.encode(date, forKey: Keys.date)
        aCoder.encode(type.rawValue, forKey: Keys.type)
    }
}
