//
//  WatchData.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-04-27.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation
import UIKit

private enum Keys {
    static let balance = "AW_DATA_BALANCE_KEY"
    static let localBalance = "AW_DATA_BALANCE_LOCAL_KEY"
    static let receiveAddress = "AW_DATA_RECEIVE_MONEY_ADDRESS"
    static let qrCode = "AW_DATA_RECEIVE_MONEY_QR_CODE"
    static let transactions = "AW_DATA_TRANSACTIONS"
    static let latestTransaction = "AW_DATA_LATEST_TRANSACTION"
    static let hasWallet = "AW_DATA_HAS_WALLET"
}

struct WatchData {
    let balance: String
    let localBalance: String
    let receiveAddress: String
    let latestTransaction: String
    let qrCode: UIImage
    let transactions: [WatchTransaction]
    let hasWallet: Bool

    var toDictionary: [String: Any] {
        return [
            Keys.balance: balance,
            Keys.localBalance: localBalance,
            Keys.receiveAddress: receiveAddress,
            Keys.latestTransaction: latestTransaction,
            Keys.qrCode: NSKeyedArchiver.archivedData(withRootObject: qrCode),
            Keys.transactions: [],
            Keys.hasWallet: hasWallet
        ]
    }

    var description: String {
        return "\(balance),\(localBalance),\(receiveAddress),\(transactions.count),\(latestTransaction),\(qrCode.size.height)"
    }
}

extension WatchData {
    init(data: [String: Any]) {
        balance = data[Keys.balance] as! String
        localBalance = data[Keys.localBalance] as! String
        receiveAddress = data[Keys.receiveAddress] as! String
        latestTransaction = data[Keys.latestTransaction] as! String
        qrCode = NSKeyedUnarchiver.unarchiveObject(with: data[Keys.qrCode] as! Data) as! UIImage
        transactions = []
        hasWallet = data[Keys.hasWallet] as! Bool
    }
}

extension WatchData : Equatable {}

func ==(lhs: WatchData, rhs: WatchData) -> Bool {
    return lhs.balance == rhs.balance && lhs.localBalance == rhs.localBalance && lhs.receiveAddress == rhs.receiveAddress && lhs.latestTransaction == rhs.latestTransaction && lhs.transactions == rhs.transactions && lhs.hasWallet == rhs.hasWallet
}
