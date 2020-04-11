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

class WalletInitializer {
    private func initializeWallet(network: Network, system: System) {
        guard network.currency.uid == Currencies.hbar.uid else { return }
        guard !system.accountIsInitialized(system.account, onNetwork: network) else { return }

        system.accountInitialize (system.account, onNetwork: network) { (res: Result<Data, System.AccountInitializationError>) in
            var serializationData: Data?
            switch res {
            case .success (let data):
                serializationData = data
                print ("[SYS] system: success: \(String(data: data, encoding: .utf8)!)")
            case .failure (let error):
                switch error {
                case .alreadyInitialized:
                    print ("[SYS] system : Already Initialized")
                case .multipleHederaAccounts(let accounts):
                    let accountDescriptions = accounts
                            .map { "{id: \($0.id), balance: \($0.balance)}"}
                    print ("[SYS] system: Multiple Hedera Accounts: \(accountDescriptions.joined(separator: ", "))")

                    // Chose the Hedera account with the largest balance - DEMO-SPECFIC
                    let hederaAccount = accounts.sorted { $0.balance > $1.balance }[0]
                    serializationData = system.accountInitialize (system.account,
                                                                  onNetwork: network,
                                                                  hedera: hederaAccount)

                case .queryFailure(let message):
                    print ("[SYS] system: Initalization Query Error: \(message)")

                case .cantCreate:
                    print ("[SYS] system: Initializaiton: Can't Create")
                }
            }

            if let serializationData = serializationData {
                print ("SYS: system: SerializationData: \(CoreCoder.hex.encode(data: serializationData)!)")
//                self.addCurrencies(for: network)
//                self.setupWalletManager(for: network)
//                DispatchQueue.main.async {
//                    Store.perform(action: ManageWallets.AddWallets(self.placeholderWalletStates))
//                }
            } else {
                print ("SYS: system: skipped hedera due to no serialization")
            }
        }
    }
}
