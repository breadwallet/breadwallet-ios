//
//  EthTx.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-10-24.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation

struct EthTxList : Codable {
    let status: String
    let message: String
    let result: [EthTx]
}

struct EthTx : Codable {
    let blockNumber: String
    let timeStamp: String
    let value: String
    let from: String
    let to: String
}
