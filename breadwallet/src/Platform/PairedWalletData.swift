//
//  PairedWalletData.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2018-07-24.
//  Copyright © 2018-2019 Breadwinner AG. All rights reserved.
//

import Foundation

/// Metadata for an EME paired wallet
class PairedWalletData: BRKVStoreObject, BRCoding {
    var classVersion: Int = 1
    var identifier: String = ""
    var service: String = ""
    var remotePubKey: String = "" // Base64-encoded string
    var created = Date.zeroValue()
    
    /// Find existing paired wallet object based on the remote public key
    init?(remotePubKey: String, store: BRReplicatedKVStore) {
        var ver: UInt64
        var date: Date
        var del: Bool
        var bytes: [UInt8]

        let storeKey = PairedWalletData.storeKey(fromRemotePubKey: remotePubKey)
        do {
            (ver, date, del, bytes) = try store.get(storeKey)
        } catch let error {
            print("Unable to initialize PairedWalletData: \(error.localizedDescription)")
            return nil
        }
        
        let bytesDat = Data(bytes: &bytes, count: bytes.count)
        super.init(key: storeKey, version: ver, lastModified: date, deleted: del, data: bytesDat)
    }
    
    /// Create new
    init(remotePubKey: String, remoteIdentifier: String, service: String) {
        super.init(key: PairedWalletData.storeKey(fromRemotePubKey: remotePubKey),
                   version: 0,
                   lastModified: Date(),
                   deleted: false,
                   data: Data())
        self.identifier = remoteIdentifier
        self.service = service
        self.remotePubKey = remotePubKey
        self.created = Date()
    }
    
    private static func storeKey(fromRemotePubKey remotePubKeyBase64: String) -> String {
        guard let remotePubKey = Data(base64Encoded: remotePubKeyBase64) else {
            assertionFailure("expect remotePubKey to be a base64-encoded string")
            return ""
        }
        return "pwd-\(remotePubKey.sha256.hexString)"
    }
    
    // MARK: - BRKVStoreObject
    
    override func getData() -> Data? {
        return BRKeyedArchiver.archivedDataWithRootObject(self)
    }
    
    override func dataWasSet(_ value: Data) {
        guard let s: PairedWalletData = BRKeyedUnarchiver.unarchiveObjectWithData(value) else { return }
        identifier = s.identifier
        service = s.service
        remotePubKey = s.remotePubKey
        created = s.created
    }
    
    // MARK: - BRCoding
    
    required public init?(coder decoder: BRCoder) {
        classVersion = decoder.decode("classVersion")
        guard classVersion != Int.zeroValue() else {
            return nil
        }
        identifier = decoder.decode("identifier")
        service = decoder.decode("service")
        remotePubKey = decoder.decode("remotePubKey")
        created = decoder.decode("created")
        super.init(key: "", version: 0, lastModified: Date(), deleted: true, data: Data())
    }
    
    func encode(_ coder: BRCoder) {
        coder.encode(classVersion, key: "classVersion")
        coder.encode(identifier, key: "identifier")
        coder.encode(service, key: "service")
        coder.encode(remotePubKey, key: "remotePubKey")
        coder.encode(created, key: "created")
    }
}
