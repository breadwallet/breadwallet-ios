//
//  CurrencyListMetaData.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2018-04-10.
//  Copyright © 2018-2019 Breadwinner AG. All rights reserved.
//

import Foundation

/// KV-store object that saves the users enabled and hidden currencies
class AssetIndex: BRKVStoreObject, Codable {
    
    static let key = "asset-index"
    
    var classVersion = 2
    var enabledAssetIds = [CurrencyId]()
    
    enum CodingKeys: String, CodingKey {
        case classVersion
        case enabledAssetIds
    }
    
    /// Create new
    init() {
        enabledAssetIds = AssetIndex.defaultCurrencyIds
        super.init(key: AssetIndex.key, version: 0, lastModified: Date(), deleted: false, data: Data())
    }
    
    /// Find existing
    init?(kvStore: BRReplicatedKVStore) {
        var ver: UInt64
        var date: Date
        var del: Bool
        var bytes: [UInt8]
        do {
            (ver, date, del, bytes) = try kvStore.get(AssetIndex.key)
            print("[KV] loading asset index ver:\(ver)...")
        } catch let e {
            print("[KV] unable to load asset index: \(e)")
            return nil
        }
        let bytesData = Data(bytes: &bytes, count: bytes.count)
        super.init(key: AssetIndex.key, version: ver, lastModified: date, deleted: del, data: bytesData)
    }
    
    override func getData() -> Data? {
        return BRKeyedArchiver.archiveData(withRootObject: self)
    }
    
    override func dataWasSet(_ value: Data) {
        guard let s: AssetIndex = BRKeyedUnarchiver.unarchiveObject(withData: value) else { return }
        enabledAssetIds = s.enabledAssetIds
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        classVersion = try container.decode(Int.self, forKey: .classVersion)
        enabledAssetIds = try container.decode([CurrencyId].self, forKey: .enabledAssetIds)
        super.init(key: "", version: 0, lastModified: Date(), deleted: true, data: Data())
    }
    
    func resetToDefault() {
        enabledAssetIds = AssetIndex.defaultCurrencyIds
    }
    
    static var defaultCurrencyIds: [CurrencyId] {
        return [
            Currencies.btc.uid,
            Currencies.eth.uid,
            Currencies.brd.uid
        ]
    }
}

/// The old asset index (formerly CurrencyListMetaData) KV-store object.
/// This declration is for supporting migration to the new index above.
class LegacyAssetIndex: BRKVStoreObject, BRCoding {
    
    static let key = "token-list-metadata-2"
    
    var classVersion = 2
    var enabledCurrencies = [String]()
    var hiddenCurrencies = [String]()
    var doesRequireSave = 0
    
    //Find existing
    init?(kvStore: BRReplicatedKVStore) {
        var ver: UInt64
        var date: Date
        var del: Bool
        var bytes: [UInt8]
        do {
            (ver, date, del, bytes) = try kvStore.get(LegacyAssetIndex.key)
        } catch let e {
            print("Unable to initialize TokenListMetaData: \(e)")
            return nil
        }
        let bytesData = Data(bytes: &bytes, count: bytes.count)
        super.init(key: LegacyAssetIndex.key, version: ver, lastModified: date, deleted: del, data: bytesData)
    }
    
    override func getData() -> Data? {
        return BRKeyedArchiver.archivedDataWithRootObject(self)
    }
    
    override func dataWasSet(_ value: Data) {
        guard let s: LegacyAssetIndex = BRKeyedUnarchiver.unarchiveObjectWithData(value) else { return }
        enabledCurrencies = s.enabledCurrencies
        hiddenCurrencies = s.hiddenCurrencies
        doesRequireSave = s.doesRequireSave
    }
    
    required public init?(coder decoder: BRCoder) {
        classVersion = decoder.decode("classVersion")
        enabledCurrencies = decoder.decode("enabledCurrencies")
        hiddenCurrencies = decoder.decode("hiddenCurrencies")
        doesRequireSave = decoder.decode("doesRequireSave")
        
        super.init(key: "", version: 0, lastModified: Date(), deleted: true, data: Data())
    }
    
    func encode(_ coder: BRCoder) {
        coder.encode(classVersion, key: "classVersion")
        coder.encode(enabledCurrencies, key: "enabledCurrencies")
        coder.encode(hiddenCurrencies, key: "hiddenCurrencies")
        coder.encode(doesRequireSave, key: "doesRequireSave")
    }
}
