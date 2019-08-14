//
//  AssetCollection.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2019-07-04.
//  Copyright © 2019 breadwallet LLC. All rights reserved.
//

import Foundation
import UIKit

/// View model for the AssetCollectionIndex KV-store object and the list of all tokens
class AssetCollection {
    typealias AssetCollectionChangeHandler = () -> Void
    
    /// All known tokens
    let allAssets: [String: CurrencyMetaData]
    
    private(set) var enabledAssets: [CurrencyMetaData] // maps to AssetIndex list
    
    /// Assets that are available to be added (have never been added)
    var availableAssets: [CurrencyMetaData] {
        let enabledKeys = Set(enabledAssets.map { $0.uid })
        return allAssets
            .filter { $0.value.isSupported && !enabledKeys.contains($0.key) }.values
            .sorted { return $0.code < $1.code }
            .sorted { return $0.isPreferred && !$1.isPreferred }
    }
    
    private(set) var hasUnsavedChanges: Bool = false
    
    private let kvStore: BRReplicatedKVStore
    private var assetIndex: AssetIndex
    
    private let didChangeAssets: AssetCollectionChangeHandler?
    
    // MARK: - Init

    /// Creates an AssetCollection based on the AssetIndex in the KV-store.
    /// If the AssetIndex is missing or empty, creates a new index with default currencies.
    /// If a LegacyAssetIndex is found it is migrated to the new AssetIndex and saved to the KV-store.
    ///
    /// - Parameters:
    ///   - kvStore: the KV-store
    ///   - allTokens: dictionary of all supported tokens, indexed by UID
    convenience init(kvStore: BRReplicatedKVStore,
                     allTokens: [String: CurrencyMetaData],
                     changeHandler: AssetCollectionChangeHandler?) {
        var assetIndex = AssetIndex(kvStore: kvStore)
            ?? AssetCollection.migrateFromOldIndex(allTokens: allTokens, kvStore: kvStore)
            ?? AssetCollection.setupInitialAssetCollection(kvStore: kvStore)
        
        if assetIndex.enabledAssetIds.isEmpty {
            print("[KV] asset index is empty. creating new index.")
            assetIndex = AssetCollection.setupInitialAssetCollection(kvStore: kvStore)
        }
        
        self.init(kvStore: kvStore,
                  allTokens: allTokens,
                  assetIndex: assetIndex,
                  changeHandler: changeHandler)
    }
    
    private init(kvStore: BRReplicatedKVStore,
                 allTokens: [String: CurrencyMetaData],
                 assetIndex: AssetIndex,
                 changeHandler: AssetCollectionChangeHandler?) {
        self.kvStore = kvStore
        self.allAssets = allTokens
        self.assetIndex = assetIndex
        self.didChangeAssets = changeHandler
        
        var foundUnsupportedTokens = false
        
        self.enabledAssets = assetIndex.enabledAssetIds.compactMap { (uid) -> CurrencyMetaData? in
            guard let metaData = allTokens[uid] else {
                print("[KV] found unsupported token in asset index: \(uid)")
                foundUnsupportedTokens = true
                return nil
            }
            return metaData
        }
        
        print("[KV] asset index initialized. enabled assets: \(enabledAssets.map { $0.code }.joined(separator: ", "))")
        
        if foundUnsupportedTokens {
            // remove unsupported token entries from the KV store
            print("[KV] removing unsupported tokens from asset index")
            assetIndex.enabledAssetIds.removeAll { allTokens[$0] == nil }
            _ = AssetCollection.save(assetIndex, kvStore: kvStore)
        }
    }
    
    // MARK: - Public
    
    func displayOrder(for asset: CurrencyMetaData) -> Int? {
        return enabledAssets.firstIndex(of: asset)
    }
    
    func availableAsset(at index: Int) -> CurrencyMetaData? {
        guard availableAssets.indices.contains(index) else { assertionFailure(); return nil }
        return availableAssets[index]
    }
    
    func add(asset: CurrencyMetaData) {
        guard !enabledAssets.contains(asset) else { return assertionFailure() }
        enabledAssets.append(asset)
        hasUnsavedChanges = true
    }
    
    func remove(asset: CurrencyMetaData) {
        guard let index = enabledAssets.firstIndex(where: { $0.uid == asset.uid }) else { return assertionFailure() }
        removeAsset(at: index)
    }
    
    func removeAsset(at index: Int) {
        guard enabledAssets.indices.contains(index) else { return assertionFailure() }
        enabledAssets.remove(at: index)
        hasUnsavedChanges = true
    }
    
    func moveAsset(from sourceIndex: Int, to destinationIndex: Int) {
        guard enabledAssets.indices.contains(sourceIndex),
            enabledAssets.indices.contains(destinationIndex) else { return assertionFailure() }
        enabledAssets.insert(enabledAssets.remove(at: sourceIndex), at: destinationIndex)
        hasUnsavedChanges = true
    }
    
    func resetToDefaultCollection() {
        assetIndex = AssetCollection.setupInitialAssetCollection(kvStore: kvStore)
        revertChanges()
        hasUnsavedChanges = true
    }
    
    /// Resets the asset list to the items in the AssetIndex
    func revertChanges() {
        self.enabledAssets = assetIndex.enabledAssetIds.compactMap { allAssets[$0] }
        hasUnsavedChanges = false
    }
    
    /// Saves the asset list to the AssetIndex in the KV-store, and triggers callback to handle changes
    func saveChanges() {
        assetIndex.enabledAssetIds = enabledAssets.map { $0.uid }
        guard save(assetIndex, kvStore: kvStore) else { return }
        if hasUnsavedChanges {
            didChangeAssets?()
            hasUnsavedChanges = false
        }
    }
    
    // MARK: - Static

    private static func setupInitialAssetCollection(kvStore: BRReplicatedKVStore) -> AssetIndex {
        print("[KV] creating new asset index")
        let newAssetIndex = AssetIndex() // sets the default currencies/networks
        _ = save(newAssetIndex, kvStore: kvStore)
        return newAssetIndex
    }

    /// Migrates from the old CurrencyListMetaData KVStore object to the new AssetCollectionIndex object
    ///
    /// - Returns: true if migration was successful, false otherwise
    private static func migrateFromOldIndex(allTokens: [String: CurrencyMetaData], kvStore: BRReplicatedKVStore) -> AssetIndex? {
        guard let oldIndex = LegacyAssetIndex(kvStore: kvStore) else { return nil }
        print("[KV] migrating to new asset index")
        
        let tokens = allTokens.values.filter { $0.tokenAddress != nil }
        let tokensByAddress = Dictionary(uniqueKeysWithValues: tokens.map { ($0.tokenAddress!, $0) })
        
        func migrate(oldKey: String) -> String? {
            if oldKey.hasPrefix(C.erc20Prefix) {
                let address = String(oldKey.dropFirst(C.erc20Prefix.count))
                return tokensByAddress[address]?.uid
            } else {
                var newKey: String?
                switch oldKey.lowercased() {
                case "btc":
                    newKey = Currencies.btc.uid
                case "bch":
                    newKey = Currencies.bch.uid
                case "eth":
                    newKey = Currencies.eth.uid
                default:
                    break
                }
                guard let key = newKey, allTokens[key] != nil else { assertionFailure(); return nil }
                return key
            }
        }
        
        let newAssetIndex = AssetIndex()
        newAssetIndex.enabledAssetIds = oldIndex.enabledCurrencies.compactMap { migrate(oldKey: $0) }
        _ = AssetCollection.save(newAssetIndex, kvStore: kvStore)
        
        return newAssetIndex
    }

    private func save(_ index: AssetIndex, kvStore: BRReplicatedKVStore) -> Bool {
        do {
            _ = try kvStore.set(index)
            try kvStore.syncKey(AssetIndex.key, completionHandler: { _ in
                
                //We need to create a new AssetIndex here for each save so that the
                //version gets incremented
                if let newAssetIndex = AssetIndex(kvStore: kvStore) {
                    self.assetIndex = newAssetIndex
                }
            })
            return true
        } catch let error {
            print("[KV] error setting wallet info: \(error)")
            return false
        }
    }
    
    private static func save(_ index: AssetIndex, kvStore: BRReplicatedKVStore) -> Bool {
        do {
            _ = try kvStore.set(index)
            try kvStore.syncKey(AssetIndex.key, completionHandler: {_ in })
            return true
        } catch let error {
            print("[KV] error setting wallet info: \(error)")
            return false
        }
    }
}
