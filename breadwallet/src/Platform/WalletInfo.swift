//
//  WalletInfo.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-03-11.
//  Copyright © 2017-2019 Breadwinner AG. All rights reserved.
//

import Foundation

class WalletInfo: BRKVStoreObject, Codable {
    static let key = "wallet-info"

    var classVersion = 3
    var name = ""
    var creationDate = Date.zeroValue()
    /// mapping of network native currency codes to WalletManagerMode
    var connectionModes = [CurrencyId: UInt8]()

    enum CodingKeys: String, CodingKey {
        case classVersion
        case name
        case creationDate
        case connectionModes
    }

    /// Create new
    init(name: String) {
        super.init(key: WalletInfo.key, version: 0, lastModified: Date(), deleted: false, data: Data())
        self.name = name
    }

    /// Find existing
    init?(kvStore: BRReplicatedKVStore) {
        var ver: UInt64
        var date: Date
        var del: Bool
        var bytes: [UInt8]
        do {
            (ver, date, del, bytes) = try kvStore.get(WalletInfo.key)
        } catch let e {
            print("[KV] unable to initialize WalletInfo: \(e)")
            return nil
        }
        let bytesData = Data(bytes: &bytes, count: bytes.count)
        super.init(key: WalletInfo.key, version: ver, lastModified: date, deleted: del, data: bytesData)
    }

    override func getData() -> Data? {
        return BRKeyedArchiver.archiveData(withRootObject: self)
    }

    override func dataWasSet(_ value: Data) {
        guard let s: WalletInfo = BRKeyedUnarchiver.unarchiveObject(withData: value) else { return }
        name = s.name
        creationDate = s.creationDate
        connectionModes = s.connectionModes
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        classVersion = try container.decode(Int.self, forKey: .classVersion)
        name = try container.decode(String.self, forKey: .name)
        creationDate = try container.decode(Date.self, forKey: .creationDate)
        connectionModes = try container.decode([CurrencyId: UInt8].self, forKey: .connectionModes)
        super.init(key: "", version: 0, lastModified: Date(), deleted: true, data: Data())
    }
}
