// 
//  KeyStoreUtils.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2020-08-12.
//  Copyright © 2020 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import Foundation

var WalletSecAttrService: String {
    if E.isRunningTests { return "com.brd.testnetQA.tests" }
    #if TESTNET
    return "com.brd.testnetQA"
    #elseif INTERNAL
    return "com.brd.internalQA"
    #else
    return "org.voisine.breadwallet"
    #endif
}

struct KeychainKey {
    public static let biometricsUnlocking = "biometricsUnlocking"
    public static let biometricsTransactions = "biometricsTransactions"
    public static let mnemonic = "mnemonic"
    public static let creationTime = "creationtime"
    public static let pin = "pin"
    public static let pinFailCount = "pinfailcount"
    public static let pinFailTime = "pinfailheight"
    public static let apiAuthKey = "authprivkey"
    public static let apiUserAccount = "https://api.breadwallet.com"
    public static let bdbClientToken = "bdbClientToken3"
    public static let bdbAuthUser = "bdbAuthUser3"
    public static let bdbAuthToken = "bdbAuthToken3"
    public static let systemAccount = "systemAccount"
    public static let seed = "seed" // deprecated
    public static let masterPubKey = "masterpubkey" // deprecated
    public static let ethPrivKey = "ethprivkey" // deprecated
    public static let fixerAPIToken = "fixerAPIToken"
    public static let cloudPinFailCount = "cloudPinFailCount"
}

func keychainItem<T>(key: String) throws -> T? {
    let query = [kSecClass as String: kSecClassGenericPassword as String,
                 kSecAttrService as String: WalletSecAttrService,
                 kSecAttrAccount as String: key,
                 kSecReturnData as String: true as Any]
    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    guard status == noErr || status == errSecItemNotFound else {
        throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
    }
    guard let data = result as? Data else { return nil }

    switch T.self {
    case is Data.Type:
        return data as? T
    case is String.Type:
        return CFStringCreateFromExternalRepresentation(secureAllocator, data as CFData,
                                                        CFStringBuiltInEncodings.UTF8.rawValue) as? T
    case is Int64.Type:
        guard data.count == MemoryLayout<T>.stride else { return nil }
        return data.withUnsafeBytes({ $0.load(as: T.self) })
    case is Dictionary<AnyHashable, Any>.Type:
        return NSKeyedUnarchiver.unarchiveObject(with: data) as? T
    default:
        throw NSError(domain: NSOSStatusErrorDomain, code: Int(errSecParam))
    }
}

func setKeychainItem<T>(key: String, item: T?, authenticated: Bool = false) throws {
    let accessible = (authenticated) ? kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String
                                     : kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String
    let query = [kSecClass as String: kSecClassGenericPassword as String,
                 kSecAttrService as String: WalletSecAttrService,
                 kSecAttrAccount as String: key]
    var status = noErr
    var data: Data?
    if let item = item {
        switch item {
        case let item as Data:
            data = item
        case let item as String:
            data = CFStringCreateExternalRepresentation(secureAllocator, item as CFString,
                                                        CFStringBuiltInEncodings.UTF8.rawValue, 0) as Data
        case let item as Int64:
            data = CFDataCreateMutable(secureAllocator, MemoryLayout<T>.stride) as Data
            [item].withUnsafeBufferPointer { data?.append($0) }
        case let item as [AnyHashable: Any]:
            data = NSKeyedArchiver.archivedData(withRootObject: item)
        default:
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(errSecParam))
        }
    }

    if data == nil { // delete item
        if SecItemCopyMatching(query as CFDictionary, nil) != errSecItemNotFound {
            status = SecItemDelete(query as CFDictionary)
        }
    } else if SecItemCopyMatching(query as CFDictionary, nil) != errSecItemNotFound { // update existing item
        let update = [kSecAttrAccessible as String: accessible,
                      kSecValueData as String: data as Any]
        status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
    } else { // add new item
        let item = [kSecClass as String: kSecClassGenericPassword as String,
                    kSecAttrService as String: WalletSecAttrService,
                    kSecAttrAccount as String: key,
                    kSecAttrAccessible as String: accessible,
                    kSecValueData as String: data as Any]
        status = SecItemAdd(item as CFDictionary, nil)
    }

    guard status == noErr else {
        throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
    }
}
