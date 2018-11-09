//
//  CurrencyListMetaData.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2018-04-10.
//  Copyright © 2018 breadwallet LLC. All rights reserved.
//

import Foundation

let tokenListMetaDataKey = "token-list-metadata-2"

class CurrencyListMetaData: BRKVStoreObject, BRCoding {
    
    var classVersion = 2
    var enabledCurrencies = [String]()
    var hiddenCurrencies = [String]()
    var doesRequireSave = 0

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
        doesRequireSave = s.doesRequireSave
    }

    required public init?(coder decoder: BRCoder) {
        classVersion = decoder.decode("classVersion")
        enabledCurrencies = decoder.decode("enabledCurrencies")
        hiddenCurrencies = decoder.decode("hiddenCurrencies")
        doesRequireSave = decoder.decode("doesRequireSave")

        //Upgrade Testflight users from a time before hiding currencies was possible
        if classVersion == 1 {
            enabledCurrencies = CurrencyListMetaData.defaultCurrencies + enabledCurrencies
            doesRequireSave = 1
        }

        super.init(key: "", version: 0, lastModified: Date(), deleted: true, data: Data())
    }

    func encode(_ coder: BRCoder) {
        coder.encode(classVersion, key: "classVersion")
        coder.encode(enabledCurrencies, key: "enabledCurrencies")
        coder.encode(hiddenCurrencies, key: "hiddenCurrencies")
        coder.encode(doesRequireSave, key: "doesRequireSave")
    }

    class var defaultCurrencies: [String] {
        return [Currencies.btc.code,
                Currencies.bch.code,
                Currencies.eth.code,
                "\(C.erc20Prefix)\(Currencies.brd.address)"]
    }
}

extension CurrencyListMetaData {

    var previouslyAddedTokenAddresses: [String] {
        return (enabledCurrencies + hiddenCurrencies).filter { $0.hasPrefix(C.erc20Prefix) }.map { $0.replacingOccurrences(of: C.erc20Prefix, with: "") }
    }
    
    var enabledTokenAddresses: [String] {
        return enabledCurrencies.filter { $0.hasPrefix(C.erc20Prefix) }.map { $0.replacingOccurrences(of: C.erc20Prefix, with: "") }
    }
    
    var enabledNonTokenCurrencies: [String] {
        return enabledCurrencies.filter { !$0.hasPrefix(C.erc20Prefix) }
    }

    var hiddenTokenAddresses: [String] {
        return hiddenCurrencies.filter { $0.hasPrefix(C.erc20Prefix) }.map { $0.replacingOccurrences(of: C.erc20Prefix, with: "") }
    }
    
    var hiddenNonTokenCurrencies: [String] {
        return hiddenCurrencies.filter { !$0.hasPrefix(C.erc20Prefix) }
    }
    
    //eg. address = ["0x722dd3f80bac40c951b51bdd28dd19d435762180", "0x3efd578b271d034a69499e4a2d933c631d44b9ad"]
    func addTokenAddresses(addresses: [String]) {
        hiddenCurrencies = hiddenNonTokenCurrencies + hiddenTokenAddresses.filter { return !addresses.contains($0) }.map { C.erc20Prefix + $0 }
        enabledCurrencies += addresses.map { C.erc20Prefix + $0 }
    }
    
    func removeTokenAddresses(addresses: [String]) {
        enabledCurrencies = enabledNonTokenCurrencies + enabledTokenAddresses.filter { return !addresses.contains($0) }.map { C.erc20Prefix + $0 }
        hiddenCurrencies += addresses.map { C.erc20Prefix + $0 }
    }
}
