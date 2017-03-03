//
//  FeeUpdater.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-03-02.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation

class FeeUpdater {

    //MARK: - Public
    init(walletManager: WalletManager, apiClient: BRAPIClient) {
        self.walletManager = walletManager
        self.apiClient = apiClient
    }

    func updateWalletFees() {
        guard feePerKb < maxFeePerKB && feePerKb > minFeePerKB else {
            self.walletManager.wallet?.feePerKb = defaultFeePerKB
            return
        }
        self.walletManager.wallet?.feePerKb = feePerKb
    }

    func refresh(completion: (() -> Void)? = nil) {
        apiClient.feePerKb { newFee, error in
            guard error == nil else { print("feePerKb error: \(error)"); completion?(); return }
            self.feePerKb = newFee
            self.updateWalletFees()
            completion?()
        }

        if timer == nil {
            timer = Timer.scheduledTimer(timeInterval: feeUpdateInterval, target: self, selector: #selector(intervalRefresh), userInfo: nil, repeats: true)
        }
    }

    @objc func intervalRefresh() {
        refresh(completion: nil)
    }

    var feePerKb: UInt64 {
        get {
            return UInt64(UserDefaults.standard.double(forKey: feeKey))
        }
        set {
            UserDefaults.standard.set(newValue, forKey: feeKey)
        }
    }

    //MARK: - Private
    private let walletManager: WalletManager
    private let apiClient: BRAPIClient
    private let feeKey = "FEE_PER_KB"
    private let txFeePerKb: UInt64 = 1000
    private let defaultFeePerKB: UInt64 = (5000*1000 + 99)/100 // bitcoind 0.11 min relay fee on 100bytes
    private lazy var minFeePerKB: UInt64 = {
        return ((self.txFeePerKb*1000 + 190)/191) // minimum relay fee on a 191byte tx
    }()
    private let maxFeePerKB: UInt64 = ((100100*1000 + 190)/191) // slightly higher than a 1000bit fee on a 191byte tx
    private var timer: Timer?
    private let feeUpdateInterval: TimeInterval = 15

}
