//
//  FeeManager.swift
//  litewallet
//
//  Created by Kerry Washington on 2/29/20.
//  Copyright © 2020 Litecoin Foundation. All rights reserved.

import Foundation
import FirebaseAnalytics
 
// this is the default that matches the mobile-api if the server is unavailable
fileprivate let defaultEconomyFeePerKB: UInt64 = 2500 // From legacy minimum. default min is 1000 as Litecoin Core version v0.17.1 
fileprivate let defaultRegularFeePerKB: UInt64 = 25000
fileprivate let defaultLuxuryFeePerKB: UInt64 = 66746
fileprivate let defaultTimestamp: UInt64 = 1583015199122

struct Fees: Equatable {
    let luxury: UInt64
    let regular: UInt64
    let economy: UInt64
    let timestamp: UInt64
    
    static var usingDefaultValues: Fees {
        return Fees(luxury: defaultLuxuryFeePerKB,
                    regular: defaultRegularFeePerKB,
                    economy: defaultEconomyFeePerKB,
                    timestamp: defaultTimestamp)
    }
}
 
enum FeeType {
    case regular
    case economy
    case luxury
}

class FeeUpdater : Trackable {
    
    //MARK: - Private
    private let walletManager: WalletManager
    private let store: Store
    private lazy var minFeePerKB: UInt64 = {
        return Fees.usingDefaultValues.economy
    }()
    private let maxFeePerKB = Fees.usingDefaultValues.luxury
    private var timer: Timer?
    private let feeUpdateInterval: TimeInterval = 15 //meet Nyquist for api server interval (30)
    
    //MARK: - Public
    init(walletManager: WalletManager, store: Store) {
        self.walletManager = walletManager
        self.store = store
    }

    func refresh(completion: @escaping () -> Void) {
        walletManager.apiClient?.feePerKb { newFees, error in
            
            guard error == nil else {
                let properties: [String : String] = ["ERROR_MESSAGE":String(describing: error),"ERROR_TYPE":"FEE_PER_KB"]
                LWAnalytics.logEventWithParameters(itemName: ._20200112_ERR, properties: properties)
                completion();
                return
            }
            
            if newFees == Fees.usingDefaultValues {
                LWAnalytics.logEventWithParameters(itemName: ._20200301_DUDFPK)
                self.saveEvent("wallet.didUseDefaultFeePerKB")
            }
            
            self.store.perform(action: UpdateFees.set(newFees))
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
}
