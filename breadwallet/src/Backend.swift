//
//  Backend.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2018-08-15.
//  Copyright © 2018 breadwallet LLC. All rights reserved.
//

import Foundation

class Backend {
    
    // MARK: - Singleton
    
    private static let shared = Backend()
    private init() {
        apiClient = BRAPIClient(authenticator: NoAuthAuthenticator())
    }
    
    // MARK: - Private
    
    private var apiClient: BRAPIClient
    private var pigeonExchange: PigeonExchange?
    private var exchangeUpdater: ExchangeUpdater?
    private var feeUpdaters = [FeeUpdater]()
    
    // MARK: - Public
    
    static var apiClient: BRAPIClient {
        return shared.apiClient
    }
    
    static var kvStore: BRReplicatedKVStore? {
        return shared.apiClient.kv
    }
    
    static var pigeonExchange: PigeonExchange? {
        return shared.pigeonExchange
    }
    
    static func updateExchangeRates(completion: (() -> Void)? = nil) {
        shared.exchangeUpdater?.refresh {
            completion?()
        }
    }

    static func updateFees() {
        shared.feeUpdaters.forEach { $0.refresh() }
    }
    
    // MARK: Setup
    
    static func connectWallet(_ authenticator: WalletAuthenticator, currencies: [CurrencyDef], walletManagers: [WalletManager]) {
        shared.apiClient = BRAPIClient(authenticator: authenticator)
        shared.pigeonExchange = PigeonExchange()
        
        shared.exchangeUpdater = ExchangeUpdater(currencies: Store.state.currencies)
        
        var added = [String]()
        walletManagers.forEach {
            if !added.contains($0.currency.code) {
                added.append($0.currency.code)
                shared.feeUpdaters.append(FeeUpdater(walletManager: $0))
            }
        }
    }
    
    static func disconnectWallet() {
        shared.feeUpdaters.forEach { $0.stop() }
        shared.feeUpdaters.removeAll()
        shared.exchangeUpdater = nil
        shared.pigeonExchange = nil
        shared.apiClient = BRAPIClient(authenticator: NoAuthAuthenticator())
    }
}
