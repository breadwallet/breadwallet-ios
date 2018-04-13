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
}

struct Fees : Codable {
    let regular: UInt64
    let economy: UInt64
    let gasPrice: UInt256
    let timestamp: TimeInterval
    
    init(regular: UInt64, economy: UInt64, timestamp: TimeInterval) {
        self.timestamp = timestamp
        self.regular = regular
        self.economy = economy
        self.gasPrice = 0
    }
    
    init(gasPrice: UInt256, timestamp: TimeInterval) {
        self.timestamp = timestamp
        self.regular = 0
        self.economy = 0
        self.gasPrice = gasPrice
    }
    
    func fee(forLevel level: FeeLevel) -> UInt64 {
        switch level {
        case .economy:
            return economy
        case .regular:
            return regular
        }
    }
}

class FeeUpdater : Trackable {

    //MARK: - Public
    
    init(walletManager: WalletManager) {
        self.walletManager = walletManager
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

    //MARK: - Private
    
    private let walletManager: WalletManager
    private var timer: Timer?
    private let feeUpdateInterval: TimeInterval = 15
    
    private func refreshBitcoin(completion: @escaping () -> Void) {
        // Bitcoin-specific constants
        let txFeePerKb: UInt64 = 1000
        let minFeePerKB: UInt64 = (txFeePerKb*1000 + 190)/191 // minimum relay fee on a 191byte tx
        let maxFeePerKB: UInt64 = ((1000100*1000 + 190)/191) // slightly higher than a 10000bit fee on a 191byte tx
        
        walletManager.apiClient?.feePerKb(code: walletManager.currency.code) { [weak self] newFees, error in
            guard let `self` = self else { return }
            guard error == nil else { print("feePerKb error: \(String(describing: error))"); completion(); return }
            if self.walletManager.currency.matches(Currencies.btc) {
                guard newFees.regular < maxFeePerKB && newFees.economy > minFeePerKB else {
                    self.saveEvent("wallet.didUseDefaultFeePerKB")
                    return
                }
            }
            Store.perform(action: WalletChange(self.walletManager.currency).setFees(newFees))
            completion()
        }
    }
    
    private func refreshEthereum(completion: @escaping () -> Void) {
        walletManager.apiClient?.getGasPrice { [weak self] result in
            guard let `self` = self else { return }
            if case .success(let gasPrice) = result {
                let newFees = Fees(gasPrice: gasPrice, timestamp: Date().timeIntervalSince1970)
                (self.walletManager as? EthWalletManager)?.gasPrice = gasPrice
                Store.perform(action: WalletChange(self.walletManager.currency).setFees(newFees))
                completion()
            } else if case .error(let error) = result {
                print("getGasPrice error: \(String(describing: error))");
                completion()
            }
        }
    }
}
