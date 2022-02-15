//
//  UserDefaultsUpdater.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-05-27.
//  Copyright © 2017-2019 Breadwinner AG. All rights reserved.
//

import Foundation

private enum AppGroup {
    #if TESTNET
    static let id = "group.cash.just.testnetQA"
    #elseif INTERNAL
    static let id = "group.cash.just.internalQA"
    #else
    static let id = "group.cash.just.breadwallet"
    #endif
    static let requestDataKey = "kBRSharedContainerDataWalletRequestDataKey"
    static let receiveAddressKey = "kBRSharedContainerDataWalletReceiveAddressKey"
}
