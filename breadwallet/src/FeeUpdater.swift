//
//  FeeUpdater.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-03-02.
//  Copyright © 2017-2019 Breadwinner AG. All rights reserved.
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

//TODO:CRYPTO fee updater to be replaced by BlockchainDB
class FeeUpdater: Trackable {

    // MARK: - Public
    
    init(currency: Currency) {
        self.currency = currency

        //TODO:CRYPTO
        // set default fee for BCH
//        if walletManager.currency.isBitcoinCash {
//            walletManager.wallet?.feePerKb = 1000
//        }
    }

    func refresh(completion: @escaping () -> Void) {
        if currency.isBitcoin {
            refreshBitcoin(completion: completion)
        } else if currency.isEthereumCompatible {
            //TODO:CRYPTO FeeUpdater to be replaced by BlockchainDB-supplied FeeBasis
            //refreshEthereum(completion: completion)
        } else {
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
    
    private let currency: Currency
    private var timer: Timer?
    private let feeUpdateInterval: TimeInterval = 15
    
    private func refreshBitcoin(completion: @escaping () -> Void) {
        // Bitcoin-specific constants
        let txFeePerKb: UInt64 = TX_FEE_PER_KB
        let minFeePerKB: UInt64 = txFeePerKb
        let maxFeePerKB: UInt64 = ((txFeePerKb*1000100 + 190)/191) // slightly higher than a 10,000bit fee on a 191byte tx
        
        Backend.apiClient.feePerKb(code: currency.code) { [weak self] newFees, error in
            guard let `self` = self else { return }
            guard error == nil else { print("feePerKb error: \(String(describing: error))"); completion(); return }
            print("\(self.currency.code) fees updated: \(newFees.regular) / \(newFees.economy)")
            if self.currency.isBitcoin {
                guard newFees.priority < maxFeePerKB && newFees.economy > minFeePerKB else {
                    self.saveEvent("wallet.didUseDefaultFeePerKB")
                    return
                }
            }
            Store.perform(action: WalletChange(self.currency).setFees(newFees))
            completion()
        }
    }

    //TODO:CRYPTO replace with BlockchainDB
    
    private func refreshEthereum(completion: @escaping () -> Void) {
        Backend.apiClient.getGasPrice { [weak self] result in
            guard let `self` = self else { return }
            if case .success(let gasPrice) = result {
                let newFees = Fees(gasPrice: gasPrice, timestamp: Date().timeIntervalSince1970)
//                print("gas price updated: \(newFees.gasPrice.string(decimals: Ethereum.Units.gwei.decimals)) gwei")
//                (self.walletManager as? EthWalletManager)?.gasPrice = gasPrice
                Store.perform(action: WalletChange(self.currency).setFees(newFees))
                completion()
            } else if case .error(let error) = result {
                print("getGasPrice error: \(String(describing: error))")
                completion()
            }
        }
    }
}
