//
//  SimpleUTXO.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-06-14.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation
import BRCore

struct SimpleUTXO {

    let hash: UInt256
    let index: UInt32
    let script: [UInt8]
    let satoshis: UInt64

    init?(json: [String: Any]) {
        guard let txid = json["txid"] as? String,
            let vout = json["vout"] as? Int,
            let scriptPubKey = json["scriptPubKey"] as? String,
            let satoshis = json["satoshis"] as? UInt64 else { return nil }
        guard let hashData = txid.hexToData,
            let scriptData = scriptPubKey.hexToData else { return nil }

        self.hash = hashData.reverse.uInt256
        self.index = UInt32(vout)
        self.script = [UInt8](scriptData)
        self.satoshis = satoshis
    }
}
