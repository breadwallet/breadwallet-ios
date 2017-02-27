//
//  TestHelpers.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-02-26.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation

func clearKeychain() {
    let classes = [kSecClassGenericPassword as String,
                   kSecClassInternetPassword as String,
                   kSecClassCertificate as String,
                   kSecClassKey as String,
                   kSecClassIdentity as String]
    classes.forEach { className in
        SecItemDelete([kSecClass as String: className]  as CFDictionary)
    }
}
