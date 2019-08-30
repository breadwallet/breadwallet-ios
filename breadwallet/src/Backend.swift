//
//  Backend.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2018-08-15.
//  Copyright © 2018-2019 Breadwinner AG. All rights reserved.
//

import Foundation
import WebKit

class Backend {
    
    // MARK: - Singleton
    
    private static let shared = Backend()
    private init() {
        apiClient = BRAPIClient(authenticator: NoAuthWalletAuthenticator())
    }
    
    // MARK: - Private
    
    private var apiClient: BRAPIClient
    private var kvStore: BRReplicatedKVStore?
    private var pigeonExchange: PigeonExchange?
    private var exchangeUpdater: ExchangeUpdater?
    private var eventManager: EventManager?
    private let userAgentFetcher = UserAgentFetcher()
    
    // MARK: - Public
    
    static var isConnected: Bool {
        return (apiClient.authKey != nil)
    }
    
    static var apiClient: BRAPIClient {
        return shared.apiClient
    }
    
    static var kvStore: BRReplicatedKVStore? {
        return shared.kvStore
    }
    
    static var pigeonExchange: PigeonExchange? {
        return shared.pigeonExchange
    }

    static var eventManager: EventManager? {
        return shared.eventManager
    }
    
    static func updateExchangeRates() {
        shared.exchangeUpdater?.refresh()
    }
    
    static func sendLaunchEvent() {
        DispatchQueue.main.async { // WKWebView creation must be on main thread
            shared.userAgentFetcher.getUserAgent { userAgent in
                shared.apiClient.sendLaunchEvent(userAgent: userAgent)
            }
        }
    }
    
    // MARK: Setup
    
    static func connect(authenticator: WalletAuthenticator) {
        guard let key = authenticator.apiAuthKey else { return assertionFailure() }
        shared.apiClient = BRAPIClient(authenticator: authenticator)
        shared.kvStore = try? BRReplicatedKVStore(encryptionKey: key, remoteAdaptor: KVStoreAdaptor(client: shared.apiClient))
        shared.pigeonExchange = PigeonExchange()
        shared.exchangeUpdater = ExchangeUpdater()
        shared.eventManager = EventManager(adaptor: shared.apiClient)
    }
    
    /// Disconnect backend services and reset API auth
    static func disconnectWallet() {
        URLCache.shared.removeAllCachedResponses()
        shared.eventManager = nil
        shared.exchangeUpdater = nil
        shared.pigeonExchange = nil
        shared.kvStore = nil
        shared.apiClient = BRAPIClient(authenticator: NoAuthWalletAuthenticator())
    }
}

// MARK: - 

class UserAgentFetcher {
    lazy var webView: WKWebView = { return WKWebView(frame: .zero) }()
    
    func getUserAgent(completion: @escaping (String) -> Void) {
        webView.loadHTMLString("<html></html>", baseURL: nil)
        webView.evaluateJavaScript("navigator.userAgent") { (result, error) in
            guard let agent = result as? String else {
                print(String(describing: error))
                return completion("")
            }
            completion(agent)
        }
    }
}
