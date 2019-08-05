//
//  PairedWalletIndex.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2018-07-24.
//  Copyright © 2018-2019 Breadwinner AG. All rights reserved.
//

import Foundation

/// Index of all EME paired wallets
class PairedWalletIndex: BRKVStoreObject, BRCoding {
    static let storeKey = "paired-wallet-index"
    
    var classVersion: Int = 1
    var pubKeys = [String]()
    var services = [String]()
    var hasPairedWallets: Bool {
        return !pubKeys.isEmpty
    }

    /// Find existing
    init?(store: BRReplicatedKVStore) {
        var ver: UInt64
        var date: Date
        var del: Bool
        var bytes: [UInt8]
        
        do {
            (ver, date, del, bytes) = try store.get(PairedWalletIndex.storeKey)
        } catch let error {
            print("Unable to initialize PairedWalletIndex: \(error.localizedDescription)")
            return nil
        }
        
        let bytesData = Data(bytes: &bytes, count: bytes.count)
        super.init(key: PairedWalletIndex.storeKey, version: ver, lastModified: date, deleted: del, data: bytesData)
    }
    
    /// Create new
    init() {
        super.init(key: PairedWalletIndex.storeKey,
                   version: 0,
                   lastModified: Date(),
                   deleted: false,
                   data: Data())
    }
    
    // MARK: - BRKVStoreObject
    
    override func getData() -> Data? {
        return BRKeyedArchiver.archivedDataWithRootObject(self)
    }
    
    override func dataWasSet(_ value: Data) {
        guard let s: PairedWalletIndex = BRKeyedUnarchiver.unarchiveObjectWithData(value) else { return }
        pubKeys = s.pubKeys
        services = s.services
    }
    
    // MARK: - BRCoding
    
    required public init?(coder decoder: BRCoder) {
        classVersion = decoder.decode("classVersion")
        guard classVersion != Int.zeroValue() else {
            return nil
        }
        pubKeys = decoder.decode("pubKeys")
        services = decoder.decode("services")
        super.init(key: "", version: 0, lastModified: Date(), deleted: true, data: Data())
    }
    
    func encode(_ coder: BRCoder) {
        coder.encode(classVersion, key: "classVersion")
        coder.encode(pubKeys, key: "pubKeys")
        coder.encode(services, key: "services")
    }
}
