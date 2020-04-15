// 
//  WalletInitializer.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2020-04-11.
//  Copyright © 2020 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import Foundation
import WalletKit

extension CoreSystem {
    
    func initialize(network: Network, system: System, callback: @escaping (Data?) -> Void) {
        system.accountInitialize(system.account, onNetwork: network, createIfDoesNotExist: false) { (res: Result<Data, System.AccountInitializationError>) in
            var serializationData: Data?
            switch res {
            case .success (let data):
                print("[SYS] system : success : \(data)")
                serializationData = data
            case .failure (let error):
                switch error {
                case .alreadyInitialized:
                    print("[SYS] system : Already Initialized")
                case .multipleHederaAccounts(let accounts):
                    print("[SYS] system: Multiple Hedera Accounts: \(accounts)")
                    let hederaAccount = accounts.sorted { ($0.balance ?? 0) > ($1.balance ?? 0) }[0]
                    serializationData = system.accountInitialize(system.account,
                                                                  onNetwork: network,
                                                                  hedera: hederaAccount)
                case .queryFailure(let message):
                    print("[SYS] system: Initalization Query Error: \(message)")
                // Account doesn't exists
                case .cantCreate:
                    print("[SYS] system: Initializaiton: Can't Create")
                }
            }
            callback(serializationData)
        }
    }
    
    func createAccount() {
        
    }
    
}
