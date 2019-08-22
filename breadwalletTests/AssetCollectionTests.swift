//
//  AssetCollectionTests.swift
//  breadwalletTests
//
//  Created by Adrian Corscadden on 2018-04-18.
//  Copyright © 2018-2019 Breadwinner AG. All rights reserved.
//

import XCTest
@testable import breadwallet

class AssetCollectionTests: XCTestCase {

    // uid, code
    static var testTokenData = [("btc", "btc"),
                                ("bch", "bch"),
                                ("eth", "eth"),
                                ("brd", "brd"),
                                ("dai", "dai"),
                                ("tusd", "tusd"),
                                ("xrp", "xrp"),
                                ("eos", "eos"),
                                ("zrx", "zrx")]

    
    var allTokens: [String: CurrencyMetaData] {
        return Dictionary(uniqueKeysWithValues: AssetCollectionTests.testTokenData.map { (uid, code) -> (String, CurrencyMetaData) in
            return (uid, CurrencyMetaData(uid: uid, code: code))
        })
    }
    var defaultAssets: [CurrencyMetaData] = AssetIndex.defaultCurrencyIds.map { CurrencyMetaData(uid: $0, code: $0) }
    var availableAssets: [CurrencyMetaData] {
        return AssetCollectionTests.testTokenData
            .filter { !AssetIndex.defaultCurrencyIds.contains($0.0) }
            .map { CurrencyMetaData(uid: $0.0, code: $0.1) }
        
    }
    
    private var client: BRAPIClient?
    private var keyStore: KeyStore!
    private var kvStore: BRReplicatedKVStore! {
        guard let kv = client?.kv else { XCTFail("KV store should exist"); return nil }
        return kv
    }
    
    override func setUp() {
        super.setUp()
        clearKeychain()
        deleteKvStoreDb()
        keyStore = try! KeyStore.create()
        _ = setupNewAccount(keyStore: keyStore)
        client = BRAPIClient(authenticator: keyStore)
    }
    
    override func tearDown() {
        super.tearDown()
        clearKeychain()
        keyStore.destroy()
    }
    
    func testInitWithDefaultAssets() {
        let collection = AssetCollection(kvStore: kvStore, allTokens: allTokens, changeHandler: nil)
        XCTAssert(collection.allAssets == allTokens)
        XCTAssert(collection.availableAssets == availableAssets)
    }
    
    func testMigrationFromOldIndex() {
        //TODO
    }
    
    func testModifyingAssetList() {
        let collection = AssetCollection(kvStore: kvStore, allTokens: allTokens, changeHandler: nil)
        let asset1 = collection.availableAssets.first!
        let asset2 = collection.availableAssets.last!
        XCTAssert(collection.displayOrder(for: asset1) == nil)
        
        // add
        collection.add(asset: asset1)
        XCTAssertFalse(collection.availableAssets.contains(asset1))
        XCTAssertEqual(collection.displayOrder(for: asset1), collection.enabledAssets.count-1)
        collection.add(asset: asset2)
        XCTAssertFalse(collection.availableAssets.contains(asset2))
        XCTAssertEqual(collection.displayOrder(for: asset2), collection.enabledAssets.count-1)
        
        // move
        let asset1Index = collection.displayOrder(for: asset1)
        XCTAssert(asset1Index != nil)
        collection.moveAsset(from: asset1Index!, to: 0)
        XCTAssertEqual(collection.displayOrder(for: asset1), 0)
        
        // remove
        collection.remove(asset: asset1)
        XCTAssertNil(collection.displayOrder(for: asset1))
        XCTAssertTrue(collection.availableAssets.contains(asset1))
        
        // re-add
        collection.add(asset: asset1)
        XCTAssertEqual(collection.displayOrder(for: asset1), collection.enabledAssets.count-1)
        XCTAssertFalse(collection.availableAssets.contains(asset1))
        
    }
    
    func testRevertChanges() {
        let collection = AssetCollection(kvStore: kvStore, allTokens: allTokens, changeHandler: nil)
        
        XCTAssert(collection.availableAssets == availableAssets)
        
        var numAdded = 0
        
        for asset in collection.availableAssets {
            collection.add(asset: asset)
            numAdded += 1
        }
        
        for asset in collection.enabledAssets {
            collection.remove(asset: asset)
        }
        
        XCTAssertEqual(collection.enabledAssets.count, 0)
        XCTAssertEqual(collection.availableAssets.count, allTokens.count)
        
        collection.revertChanges()
        
        XCTAssert(collection.availableAssets == availableAssets)
    }
    
    
    func testResetToDefault() {
        let collection = AssetCollection(kvStore: kvStore, allTokens: allTokens, changeHandler: nil)
        XCTAssert(collection.availableAssets == availableAssets)
        collection.removeAsset(at: 0)
        collection.resetToDefaultCollection()
        XCTAssert(collection.enabledAssets.map { $0.uid } == AssetIndex.defaultCurrencyIds)
    }
    
    func testGetCurrencyMetaData() {
        let e = expectation(description: "Should receive currency metadata")
        clearCurrenciesCache()
        
        //1st fetch without cache
        client?.getCurrencyMetaData(completion: { metadata in
            let tokens = metadata.values.filter { ($0.tokenAddress != nil) && !$0.tokenAddress!.isEmpty }
            let tokensByAddress = Dictionary(uniqueKeysWithValues: tokens.map { ($0.tokenAddress!, $0) })
            XCTAssert(metadata.count > 0)
            XCTAssert(tokens.count > 0)
            XCTAssert(tokensByAddress.count > 0)
            
            //2nd fetch should hit cache
            self.client?.getCurrencyMetaData(completion: { metadata in
                let tokens = metadata.values.filter { ($0.tokenAddress != nil) && !$0.tokenAddress!.isEmpty }
                let tokensByAddress = Dictionary(uniqueKeysWithValues: tokens.map { ($0.tokenAddress!, $0) })
                XCTAssert(metadata.count > 0)
                XCTAssert(tokens.count > 0)
                XCTAssert(tokensByAddress.count > 0)
                e.fulfill()
            })
        })
        waitForExpectations(timeout: 1.0, handler: nil)
    }
    
    private func clearCurrenciesCache() {
        let fm = FileManager.default
        guard let documentsDir = try? fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false) else { return assertionFailure() }
        let currenciesPath = documentsDir.appendingPathComponent("currencies.json").path
        if fm.fileExists(atPath: currenciesPath) {
            try? fm.removeItem(atPath: currenciesPath)
        }
    }
    
}

extension CurrencyMetaData {
    init(uid: String, code: String, tokenAddress: String? = nil) {
        self.init(uid: uid,
                  code: code,
                  isSupported: true,
                  colors: (UIColor.black, UIColor.black),
                  name: "test currency",
                  tokenAddress: tokenAddress)
    }
}
