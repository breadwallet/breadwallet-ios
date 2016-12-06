//
//  WalletManager+Plat.swift
//  breadwallet
//
//  Created by Samuel Sutch on 12/5/16.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import Foundation

// Provide extensions that service the platform functionality (api client, etc)
extension WalletManager {
    public var apiClient: BRAPIClient {
        get {
            return BRAPIClient(authenticator: self)
        }
    }
}
