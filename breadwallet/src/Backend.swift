//
//  Backend.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2018-08-15.
//  Copyright © 2018 breadwallet LLC. All rights reserved.
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
    private var pigeonExchange: PigeonExchange?
    private var exchangeUpdater: ExchangeUpdater?
    //TODO:CRYPTO fee updater
    private var feeUpdaters = [FeeUpdater]()
    private let userAgentFetcher = UserAgentFetcher()
    
    // MARK: - Public
    
    static var isConnected: Bool {
        return (apiClient.authKey != nil)
    }
    
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

    //TODO:CRYPTO fee updater
    static func updateFees() {
        shared.feeUpdaters.forEach { $0.refresh() }
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
        shared.apiClient = BRAPIClient(authenticator: authenticator)
        shared.pigeonExchange = PigeonExchange()

        shared.exchangeUpdater = ExchangeUpdater()
    }

    //TODO:CRYPTO fee updater
    static func setupFeeUpdater(for currency: Currency) {
        let feeUpdater = FeeUpdater(currency: currency)
        shared.feeUpdaters.append(feeUpdater)
        feeUpdater.refresh()
    }
    
    static func disconnectWallet() {
        shared.feeUpdaters.forEach { $0.stop() }
        shared.feeUpdaters.removeAll()
        shared.exchangeUpdater = nil
        shared.pigeonExchange = nil
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
