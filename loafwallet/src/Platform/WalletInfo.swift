//
//  WalletInfo.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-03-11.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation

let walletInfoKey = "wallet-info"

class WalletInfo : BRKVStoreObject, BRCoding {
    var classVersion = 2
    var name = ""
    var creationDate = Date.zeroValue()

    //Create new
    init(name: String) {
        super.init(key: walletInfoKey, version: 0, lastModified: Date(), deleted: false, data: Data())
        self.name = name
    }

    //Find existing
    init?(kvStore: BRReplicatedKVStore) {
        var ver: UInt64
        var date: Date
        var del: Bool
        var bytes: [UInt8]
        do {
            (ver, date, del, bytes) = try kvStore.get(walletInfoKey)
        } catch let e {
            print("Unable to initialize WalletInfo: \(e)")
            return nil
        }
        let bytesData = Data(bytes: &bytes, count: bytes.count)
        super.init(key: walletInfoKey, version: ver, lastModified: date, deleted: del, data: bytesData)
    }

    override func getData() -> Data? {
        return BRKeyedArchiver.archivedDataWithRootObject(self)
    }

    override func dataWasSet(_ value: Data) {
        guard let s: WalletInfo = BRKeyedUnarchiver.unarchiveObjectWithData(value) else { return }
        name = s.name
        creationDate = s.creationDate
    }

    required public init?(coder decoder: BRCoder) {
        classVersion = decoder.decode("classVersion")
        name = decoder.decode("name")
        creationDate = decoder.decode("creationDate")
        super.init(key: "", version: 0, lastModified: Date(), deleted: true, data: Data())
    }

    func encode(_ coder: BRCoder) {
        coder.encode(classVersion, key: "classVersion")
        coder.encode(name, key: "name")
        coder.encode(creationDate, key: "creationDate")
    }
}
