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
class AssetCollection: Subscriber {
    typealias AssetCollectionChangeHandler = () -> Void
    
    /// All known tokens
    let allAssets: [CurrencyId: CurrencyMetaData]
    
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
                     allTokens: [CurrencyId: CurrencyMetaData],
                     changeHandler: AssetCollectionChangeHandler?) {
        let assetIndex = AssetIndex(kvStore: kvStore)
            ?? AssetCollection.migrateFromOldIndex(allTokens: allTokens, kvStore: kvStore)
            ?? AssetCollection.setupInitialAssetCollection(kvStore: kvStore)

        var saveRequired = false
        
        if assetIndex.enabledAssetIds.isEmpty {
            print("[KV] asset index is empty. creating new index.")
            assetIndex.resetToDefault()
            saveRequired = true
        }
        
        self.init(kvStore: kvStore,
                  allTokens: allTokens,
                  assetIndex: assetIndex,
                  changeHandler: changeHandler,
                  saveRequired: saveRequired)
    }
    
    private init(kvStore: BRReplicatedKVStore,
                 allTokens: [CurrencyId: CurrencyMetaData],
                 assetIndex: AssetIndex,
                 changeHandler: AssetCollectionChangeHandler?,
                 saveRequired: Bool) {
        self.kvStore = kvStore
        self.allAssets = allTokens
        self.assetIndex = assetIndex
        self.didChangeAssets = changeHandler
        self.hasUnsavedChanges = saveRequired
        
        var foundUnsupportedTokens = false
        
        self.enabledAssets = assetIndex.enabledAssetIds.compactMap { (uid) -> CurrencyMetaData? in
            guard let metaData = allTokens[uid] else {
                print("[KV] found unsupported token in asset index: \(uid)")
                foundUnsupportedTokens = true
                return nil
            }
            return metaData
        }
        
        print("[KV] asset index (ver: \(assetIndex.version)) initialized. enabled assets: \(enabledAssets.map { $0.code }.joined(separator: ", "))")
        
        if foundUnsupportedTokens {
            // remove unsupported token entries from the KV store
            print("[KV] removing unsupported tokens from asset index")
            assetIndex.enabledAssetIds.removeAll { allTokens[$0] == nil }
            hasUnsavedChanges = true
        }

        if assetIndex.enabledAssetIds.isEmpty {
            resetToDefaultCollection()
        }
        if hasUnsavedChanges {
            _ = save()
        }
        
        Store.subscribe(self, name: .didSyncKVStore) { [weak self] _ in
            guard let `self` = self else { return }
            if let newAssetIndex = AssetIndex(kvStore: self.kvStore), newAssetIndex.version > self.assetIndex.version {
                assert(self.hasUnsavedChanges == false)
                print("[KV] asset index reloaded")
                self.assetIndex = newAssetIndex
                self.revertChanges()
                self.didChangeAssets?()
            }
        }
    }
    
    deinit {
        Store.unsubscribe(self)
    }
    
    // MARK: - Public

    func isEnabled(_ currencyId: CurrencyId) -> Bool {
        return enabledAssets.contains { $0.uid == currencyId }
    }
    
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
        print("[KV] resetting asset index")
        assetIndex.resetToDefault()
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
        if hasUnsavedChanges && save() {
            didChangeAssets?()
            hasUnsavedChanges = false
        }
    }
    
    // MARK: - Static

    private static func setupInitialAssetCollection(kvStore: BRReplicatedKVStore) -> AssetIndex {
        print("[KV] creating new asset index")
        let newAssetIndex = AssetIndex() // sets the default currencies/networks
        return newAssetIndex
    }

    /// Migrates from the old CurrencyListMetaData KVStore object to the new AssetCollectionIndex object
    ///
    /// - Returns: true if migration was successful, false otherwise
    private static func migrateFromOldIndex(allTokens: [CurrencyId: CurrencyMetaData], kvStore: BRReplicatedKVStore) -> AssetIndex? {
        guard let oldIndex = LegacyAssetIndex(kvStore: kvStore) else { return nil }
        print("[KV] migrating to new asset index")
        
        let tokens = allTokens.values.filter { $0.tokenAddress != nil && !$0.tokenAddress!.isEmpty }
        let tokensByAddress = Dictionary(uniqueKeysWithValues: tokens.map { ($0.tokenAddress!.lowercased(), $0) })
        
        func migrate(oldKey: String) -> CurrencyId? {
            if oldKey.hasPrefix(C.erc20Prefix) {
                let address = String(oldKey.dropFirst(C.erc20Prefix.count))
                return tokensByAddress[address.lowercased()]?.uid
            } else {
                var newKey: CurrencyId?
                switch oldKey.lowercased() {
                case Currencies.btc.code.lowercased():
                    newKey = Currencies.btc.uid
                case Currencies.bch.code.lowercased():
                    newKey = Currencies.bch.uid
                case Currencies.eth.code.lowercased():
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
        
        return newAssetIndex
    }

    private func save() -> Bool {
        do {
            guard let newAssetIndex = try kvStore.set(assetIndex) as? AssetIndex else { assertionFailure(); return false }
            self.assetIndex = newAssetIndex
            hasUnsavedChanges = false
            return true
        } catch let error {
            print("[KV] error setting asset index: \(error)")
            return false
        }
    }
}
