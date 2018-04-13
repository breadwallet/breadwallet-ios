//
//  CurrencyListMetaData.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2018-04-10.
//  Copyright © 2018 breadwallet LLC. All rights reserved.
//

import Foundation

let tokenListMetaDataKey = "token-list-metadata"

class CurrencyListMetaData : BRKVStoreObject, BRCoding {
    
    var classVersion = 1
    var enabledCurrencies = [String]()
    var hiddenCurrencies = [String]()

    //Create new
    init() {
        super.init(key: tokenListMetaDataKey, version: 0, lastModified: Date(), deleted: false, data: Data())
    }

    //Find existing
    init?(kvStore: BRReplicatedKVStore) {
        var ver: UInt64
        var date: Date
        var del: Bool
        var bytes: [UInt8]
        do {
            (ver, date, del, bytes) = try kvStore.get(tokenListMetaDataKey)
        } catch let e {
            print("Unable to initialize TokenListMetaData: \(e)")
            return nil
        }
        let bytesData = Data(bytes: &bytes, count: bytes.count)
        super.init(key: tokenListMetaDataKey, version: ver, lastModified: date, deleted: del, data: bytesData)
    }

    override func getData() -> Data? {
        return BRKeyedArchiver.archivedDataWithRootObject(self)
    }

    override func dataWasSet(_ value: Data) {
        guard let s: CurrencyListMetaData = BRKeyedUnarchiver.unarchiveObjectWithData(value) else { return }
        enabledCurrencies = s.enabledCurrencies
        hiddenCurrencies = s.hiddenCurrencies
    }

    required public init?(coder decoder: BRCoder) {
        classVersion = decoder.decode("classVersion")
        enabledCurrencies = decoder.decode("enabledCurrencies")
        hiddenCurrencies = decoder.decode("hiddenCurrencies")
        super.init(key: "", version: 0, lastModified: Date(), deleted: true, data: Data())
    }

    func encode(_ coder: BRCoder) {
        coder.encode(classVersion, key: "classVersion")
        coder.encode(enabledCurrencies, key: "enabledCurrencies")
        coder.encode(hiddenCurrencies, key: "hiddenCurrencies")
    }
}

extension CurrencyListMetaData {
    var previouslyAddedTokenAddresses: [String] {
        return (enabledCurrencies + hiddenCurrencies).filter { $0.hasPrefix(C.erc20Prefix) }.map { $0.replacingOccurrences(of: C.erc20Prefix, with: "") }
    }
    
    //eg. address = [0x722dd3f80bac40c951b51bdd28dd19d435762180", "0x3efd578b271d034a69499e4a2d933c631d44b9ad"]
    func addTokenAddresses(addresses: [String]) {
        enabledCurrencies = enabledCurrencies + addresses.map { C.erc20Prefix + $0 }
    }
}
