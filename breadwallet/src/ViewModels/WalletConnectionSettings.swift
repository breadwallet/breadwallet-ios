// 
//  WalletConnectionSettings.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2019-08-28.
//  Copyright © 2019 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import Foundation
import BRCrypto

typealias WalletConnectionMode = BRCrypto.WalletManagerMode

/// View model for the WalletConnectionSettingsViewController and WalletInfo.connectionModes model
class WalletConnectionSettings {

    private let system: CoreSystem
    private let kvStore: BRReplicatedKVStore
    private var walletInfo: WalletInfo

    init(system: CoreSystem, kvStore: BRReplicatedKVStore, walletInfo: WalletInfo) {
        self.system = system
        self.kvStore = kvStore
        self.walletInfo = walletInfo
        sanitizeAll()
    }

    static func defaultMode(for currency: Currency) -> WalletConnectionMode {
        assert(currency.tokenType == .native)
        switch currency.uid {
        case Currencies.btc.uid:
            return .p2p_only
        case Currencies.bch.uid:
            return .p2p_only
        case Currencies.eth.uid:
            return .api_only
        default:
            assertionFailure()
            return .api_only
        }
    }

    func mode(for currency: Currency) -> WalletConnectionMode {
        assert(currency.tokenType == .native)
        if let serialization = walletInfo.connectionModes[currency.uid],
            let mode = WalletManagerMode(serialization: serialization) {
            return mode
        } else {
            // valid mode not found, set to default
            assert(walletInfo.connectionModes[currency.uid] == nil, "invalid mode serialization found in kv-store")
            let mode = WalletConnectionSettings.defaultMode(for: currency)
            print("[KV] setting default mode for \(currency.uid): \(mode)")
            walletInfo.connectionModes[currency.uid] = mode.serialization
            save()
            return mode
        }
    }

    func set(mode: WalletConnectionMode, for currency: Currency) {
        assert(currency.tokenType == .native)
        assert(currency.isBitcoin || currency.isEthereum) //TODO:CRYPTO_V2
        guard system.isModeSupported(mode, for: currency.network) || E.isRunningTests else { return assertionFailure() }
        walletInfo.connectionModes[currency.uid] = mode.serialization
        guard let wm = currency.wallet?.manager else { return assert(E.isRunningTests) }
        system.setConnectionMode(mode, forWalletManager: wm)
        save()
    }

    private func save() {
        do {
            guard let newWalletInfo = try kvStore.set(walletInfo) as? WalletInfo else { return assertionFailure() }
            self.walletInfo = newWalletInfo
        } catch let error {
            print("[KV] error setting wallet info: \(error)")
        }
    }

    /// clean up any invalid modes stored in KV-store
    private func sanitizeAll() {
        [Currencies.btc.instance,
         Currencies.bch.instance,
         Currencies.eth.instance]
            .compactMap { $0 }
            .forEach { sanitize(currency: $0) }
    }

    private func sanitize(currency: Currency) {
        if let wm = currency.wallet?.manager,
            let modeValue = walletInfo.connectionModes[currency.uid],
            let mode = WalletConnectionMode(serialization: modeValue),
            !system.isModeSupported(mode, for: wm.network) {
            // replace unsupported mode with default
            walletInfo.connectionModes[currency.uid] = nil
        }
    }
}

enum WalletManagerModeOverride: Int {
    case none
    case api
    case p2p
    
    var description: String {
        switch self {
        case .none:
            return "none"
        case .api:
            return "api"
        case .p2p:
            return "p2p"
        }
    }
    
    var mode: WalletConnectionMode? {
        switch self {
        case .none:
            return nil
        case .api:
            return .api_only
        case .p2p:
            return .p2p_only
        }
    }
}
