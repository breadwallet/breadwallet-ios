//
//  FeeUpdater.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-03-02.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation
import BRCore

enum FeeLevel {
    case regular
    case economy
    case priority
}

struct Fees: Codable {
    let priority: UInt64
    let regular: UInt64
    let economy: UInt64
    let gasPrice: UInt256
    let timestamp: TimeInterval
    
    init(regular: UInt64, economy: UInt64, priority: UInt64, timestamp: TimeInterval) {
        self.timestamp = timestamp
        self.regular = regular
        self.economy = economy
        self.priority = priority
        self.gasPrice = 0
    }
    
    init(gasPrice: UInt256, timestamp: TimeInterval) {
        self.timestamp = timestamp
        self.regular = 0
        self.economy = 0
        self.priority = 0
        self.gasPrice = gasPrice
    }
    
    func fee(forLevel level: FeeLevel) -> UInt64 {
        switch level {
        case .economy:
            return economy
        case .regular:
            return regular
        case .priority:
            return priority
        }
    }
}

class FeeUpdater: Trackable {

    // MARK: - Public
    
    init(walletManager: WalletManager) {
        self.walletManager = walletManager
        
        // set default fee for BCH
        if walletManager.currency.matches(Currencies.bch) {
            walletManager.wallet?.feePerKb = 1000
        }
    }

    func refresh(completion: @escaping () -> Void) {
        switch walletManager.currency {
        case is Bitcoin:
            refreshBitcoin(completion: completion)
        case is Ethereum:
            refreshEthereum(completion: completion)
        default:
            completion()
        }
        
        if timer == nil {
            timer = Timer.scheduledTimer(timeInterval: feeUpdateInterval, target: self, selector: #selector(intervalRefresh), userInfo: nil, repeats: true)
        }
    }

    func refresh() {
        refresh(completion: {})
    }

    @objc func intervalRefresh() {
        refresh(completion: {})
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Private
    
    private let walletManager: WalletManager
    private var timer: Timer?
    private let feeUpdateInterval: TimeInterval = 15
    
    private func refreshBitcoin(completion: @escaping () -> Void) {
        // Bitcoin-specific constants
        let txFeePerKb: UInt64 = TX_FEE_PER_KB
        let minFeePerKB: UInt64 = txFeePerKb
        let maxFeePerKB: UInt64 = ((txFeePerKb*1000100 + 190)/191) // slightly higher than a 10,000bit fee on a 191byte tx
        
        Backend.apiClient.feePerKb(code: walletManager.currency.code) { [weak self] newFees, error in
            guard let `self` = self else { return }
            guard error == nil else { print("feePerKb error: \(String(describing: error))"); completion(); return }
            print("\(self.walletManager.currency.code) fees updated: \(newFees.regular) / \(newFees.economy)")
            if self.walletManager.currency is Bitcoin {
                guard newFees.priority < maxFeePerKB && newFees.economy > minFeePerKB else {
                    self.saveEvent("wallet.didUseDefaultFeePerKB")
                    return
                }
            }
            Store.perform(action: WalletChange(self.walletManager.currency).setFees(newFees))
            completion()
        }
    }
    
    private func refreshEthereum(completion: @escaping () -> Void) {
        Backend.apiClient.getGasPrice { [weak self] result in
            guard let `self` = self else { return }
            if case .success(let gasPrice) = result {
                let newFees = Fees(gasPrice: gasPrice, timestamp: Date().timeIntervalSince1970)
                print("gas price updated: \(newFees.gasPrice.string(decimals: Ethereum.Units.gwei.decimals)) gwei")
                (self.walletManager as? EthWalletManager)?.gasPrice = gasPrice
                Store.perform(action: WalletChange(self.walletManager.currency).setFees(newFees))
                completion()
            } else if case .error(let error) = result {
                print("getGasPrice error: \(String(describing: error))")
                completion()
            }
        }
    }
}
