//
//  InboxMetaData.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2018-09-04.
//  Copyright © 2018-2019 Breadwinner AG. All rights reserved.
//

import Foundation

/// Metadata for the EME inbox
class InboxMetaData: BRKVStoreObject, BRCoding {
    static let storeKey = "encrypted-message-inbox-metadata"
    
    var classVersion: Int = 1
    var lastCursor: String = ""
    
    /// Find existing paired wallet object based on the remote public key
    init?(store: BRReplicatedKVStore) {
        var ver: UInt64
        var date: Date
        var del: Bool
        var bytes: [UInt8]
        
        do {
            (ver, date, del, bytes) = try store.get(InboxMetaData.storeKey)
        } catch let error {
            print("Unable to initialize InboxMetaData: \(error.localizedDescription)")
            return nil
        }
        
        let bytesDat = Data(bytes: &bytes, count: bytes.count)
        super.init(key: InboxMetaData.storeKey, version: ver, lastModified: date, deleted: del, data: bytesDat)
    }
    
    /// Create new
    init(cursor: String) {
        super.init(key: InboxMetaData.storeKey,
                   version: 0,
                   lastModified: Date(),
                   deleted: false,
                   data: Data())
        self.lastCursor = cursor
    }
    
    // MARK: - BRKVStoreObject
    
    override func getData() -> Data? {
        return BRKeyedArchiver.archivedDataWithRootObject(self)
    }
    
    override func dataWasSet(_ value: Data) {
        guard let s: InboxMetaData = BRKeyedUnarchiver.unarchiveObjectWithData(value) else { return }
        lastCursor = s.lastCursor
    }
    
    // MARK: - BRCoding
    
    required public init?(coder decoder: BRCoder) {
        classVersion = decoder.decode("classVersion")
        guard classVersion != Int.zeroValue() else {
            return nil
        }
        lastCursor = decoder.decode("lastCursor")
        super.init(key: "", version: 0, lastModified: Date(), deleted: true, data: Data())
    }
    
    func encode(_ coder: BRCoder) {
        coder.encode(classVersion, key: "classVersion")
        coder.encode(lastCursor, key: "lastCursor")
    }
}
