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
    static let id = "group.com.fabriik.onetestnetQA"
    #elseif INTERNAL
    static let id = "group.com.fabriik.oneinternalQA"
    #else
    static let id = "group.com.fabriik.one"
    #endif
    static let requestDataKey = "kBRSharedContainerDataWalletRequestDataKey"
    static let receiveAddressKey = "kBRSharedContainerDataWalletReceiveAddressKey"
}
