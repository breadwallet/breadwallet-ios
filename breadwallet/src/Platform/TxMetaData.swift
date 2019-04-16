//
//  BRKVStoreObjects.swift
//  BreadWallet
//
//  Created by Samuel Sutch on 8/13/16.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

import Foundation
import BRCore

// MARK: - Txn Metadata

// Txn metadata stores additional information about a given transaction
open class TxMetaData: BRKVStoreObject, BRCoding {
    var classVersion: Int = 3
    
    var blockHeight: Int = 0
    var exchangeRate: Double = 0
    var exchangeRateCurrency: String = ""
    var feeRate: Double = 0
    var size: Int = 0
    var created: Date = Date.zeroValue()
    var deviceId: String = ""
    var comment = ""
    var tokenTransfer = ""

    required public init?(coder decoder: BRCoder) {
        classVersion = decoder.decode("classVersion")
        if classVersion == Int.zeroValue() {
            //print("[BRTxMetadataObject] Unable to unarchive _TXMetadata: no version")
            return nil
        }
        blockHeight = decoder.decode("bh")
        exchangeRate = decoder.decode("er")
        exchangeRateCurrency = decoder.decode("erc")
        feeRate = decoder.decode("fr")
        size = decoder.decode("s")
        deviceId = decoder.decode("dId")
        created = decoder.decode("c")
        comment = decoder.decode("comment")
        tokenTransfer = decoder.decode("tokenTransfer")
        super.init(key: "", version: 0, lastModified: Date(), deleted: true, data: Data())
    }
    
    func encode(_ coder: BRCoder) {
        coder.encode(classVersion, key: "classVersion")
        coder.encode(blockHeight, key: "bh")
        coder.encode(exchangeRate, key: "er")
        coder.encode(exchangeRateCurrency, key: "erc")
        coder.encode(feeRate, key: "fr")
        coder.encode(size, key: "s")
        coder.encode(created, key: "c")
        coder.encode(deviceId, key: "dId")
        coder.encode(comment, key: "comment")
        coder.encode(tokenTransfer, key: "tokenTransfer")
    }
    
    /// Find metadata object based on the txHash
    public convenience init?(txHash: UInt256, store: BRReplicatedKVStore) {
        self.init(txKey: txHash.txKey, store: store)
    }

    /// Find metadata object based on the txKey
    public init?(txKey: String, store: BRReplicatedKVStore) {
        var ver: UInt64
        var date: Date
        var del: Bool
        var bytes: [UInt8]

        //print("[BRTxMetadataObject] find \(txKey)")
        do {
            (ver, date, del, bytes) = try store.get(txKey)
            let bytesDat = Data(bytes: &bytes, count: bytes.count)
            super.init(key: txKey, version: ver, lastModified: date, deleted: del, data: bytesDat)
            return
        } catch _ {
            //print("[BRTxMetadataObject] Unable to initialize BRTxMetadataObject: \(String(describing: e))")
        }

        return nil
    }
    
    /// Create new transaction metadata
    init(key: String,
         transaction: Transaction,
         exchangeRate: Double,
         exchangeRateCurrency: String,
         feeRate: Double? = nil,
         deviceId: String,
         comment: String? = nil,
         tokenTransfer: String? = nil) {
        print("[BRTxMetadataObject] new \(key)")
        super.init(key: key,
                   version: 0,
                   lastModified: Date(),
                   deleted: false,
                   data: Data())
        self.blockHeight = Int(transaction.blockHeight)
        self.created = Date()
        
        self.exchangeRate = exchangeRate
        self.exchangeRateCurrency = exchangeRateCurrency
        self.feeRate = feeRate ?? 0
        
        self.deviceId = deviceId
        self.comment = comment ?? ""

        //TODO:CRYPTO btc tx size
//        if let transaction = transaction as? BtcTransaction {
//            var rawTx = transaction.rawTransaction
//            self.size = BRTransactionSize(&rawTx)
//        }

//        if transaction is EthTransaction {
            self.tokenTransfer = tokenTransfer ?? ""
//        } else {
//            self.tokenTransfer = ""
//        }
    }
    
    override func getData() -> Data? {
        return BRKeyedArchiver.archivedDataWithRootObject(self)
    }
    
    override func dataWasSet(_ value: Data) {
        guard !value.isEmpty else { return }
        guard let s: TxMetaData = BRKeyedUnarchiver.unarchiveObjectWithData(value) else {
            print("[BRTxMetadataObject] unable to deserialise tx metadata")
            return
        }
        blockHeight = s.blockHeight
        exchangeRate = s.exchangeRate
        exchangeRateCurrency = s.exchangeRateCurrency
        feeRate = s.feeRate
        size = s.size
        created = s.created
        deviceId = s.deviceId
        comment = s.comment
        tokenTransfer = s.tokenTransfer
    }

}

extension UInt256 {
    var sha256: String {
        var u = self
        return withUnsafePointer(to: &u) { p in
            let bd = Data(bytes: p, count: MemoryLayout<UInt256>.stride).sha256
            return (bd.hexString)
        }
    }

    var txKey: String {
        return "txn2-\(sha256)"
    }
    
    var tokenTxKey: String {
        return "tkxf-\(sha256)"
    }
}
