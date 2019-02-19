//
//  UserDefaultsUpdater.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-05-27.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation

private enum AppGroup {
    #if Internal
    static let id = "group.com.brd.internalQA"
    #else
    static let id = "group.org.voisine.breadwallet"
    #endif
    static let requestDataKey = "kBRSharedContainerDataWalletRequestDataKey"
    static let receiveAddressKey = "kBRSharedContainerDataWalletReceiveAddressKey"
}

// unused -- for showing address in watch/widget extensions
class UserDefaultsUpdater {

    func refresh() {
        guard let receiveAddress = Store.state[Currencies.btc]?.receiveAddress else { return }
        defaults?.set(receiveAddress as NSString, forKey: AppGroup.receiveAddressKey)
        defaults?.set(receiveAddress.data(using: .utf8), forKey: AppGroup.requestDataKey)
    }

    private lazy var defaults: UserDefaults? = {
        return UserDefaults(suiteName: AppGroup.id)
    }()

}
