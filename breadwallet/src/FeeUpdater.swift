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

    func refresh(completion: (() -> Void)? = nil) {
        apiClient.feePerKb { fee, error in
            guard error == nil else { print("feePerKb error: \(error)"); completion?(); return }
            UserDefaults.standard.set(fee, forKey: self.feeKey)
            self.walletManager.wallet?.feePerKb = fee
            completion?()
        }
    }

    //MARK: - Private
    private let walletManager: WalletManager
    private let apiClient: BRAPIClient
    private let feeKey = "FEE_PER_KB"
}
