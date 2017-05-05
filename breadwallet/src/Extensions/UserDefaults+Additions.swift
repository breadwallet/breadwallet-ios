//
//  UserDefaults+Additions.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-04-04.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation

private let defaults = UserDefaults.standard
private let isTouchIdEnabledKey = "istouchidenabled"
private let defaultCurrencyKey = "defaultcurrency"
private let hasAquiredShareDataPermissionKey = "has_acquired_permission"
private let legacyWalletNeedsBackupKey = "WALLET_NEEDS_BACKUP"
private let writePaperPhraseDateKey = "writepaperphrasedatekey"
private let hasPromptedTouchIdKey = "haspromptedtouched"
private let displayCurrencyKey = "displayCurrencyKey"

extension UserDefaults {

    static var isTouchIdEnabled: Bool {
        get {
            guard defaults.object(forKey: isTouchIdEnabledKey) != nil else {
                return false
            }
            return defaults.bool(forKey: isTouchIdEnabledKey)
        }
        set {
            defaults.set(newValue, forKey: isTouchIdEnabledKey)
        }
    }

    static var defaultCurrency: String {
        get {
            guard defaults.object(forKey: defaultCurrencyKey) != nil else {
                return  Locale.current.currencyCode ?? "USD"
            }
            return defaults.string(forKey: defaultCurrencyKey)!
        }
        set {
            defaults.set(newValue, forKey: defaultCurrencyKey)
        }
    }

    static var hasAquiredShareDataPermission: Bool {
        get {
            guard defaults.object(forKey: hasAquiredShareDataPermissionKey) != nil else {
                return  false
            }
            return defaults.bool(forKey: hasAquiredShareDataPermissionKey)
        }
        set {
            defaults.set(newValue, forKey: hasAquiredShareDataPermissionKey)
        }
    }

    static var displayCurrency: Currency {
        get {
            guard defaults.object(forKey: displayCurrencyKey) != nil else {
                return .bitcoin
            }
            let intValue = defaults.integer(forKey: displayCurrencyKey)
            return Currency(rawValue: intValue) ?? .bitcoin
        }
        set {
            defaults.set(newValue.rawValue, forKey: displayCurrencyKey)
        }
    }
}

//MARK: - Wallet Requires Backup
extension UserDefaults {
    static var legacyWalletNeedsBackup: Bool? {
        guard defaults.object(forKey: legacyWalletNeedsBackupKey) != nil else {
            return nil
        }
        return defaults.bool(forKey: legacyWalletNeedsBackupKey)
    }

    static func removeLegacyWalletNeedsBackupKey() {
        defaults.removeObject(forKey: legacyWalletNeedsBackupKey)
    }

    static var writePaperPhraseDate: Date? {
        get {
            return defaults.object(forKey: writePaperPhraseDateKey) as! Date?
        }
        set {
            defaults.set(newValue, forKey: writePaperPhraseDateKey)
        }
    }

    static var walletRequiresBackup: Bool {
        if let legacyWalletNeedsBackup = UserDefaults.legacyWalletNeedsBackup, legacyWalletNeedsBackup == true {
            return true
        }
        if UserDefaults.writePaperPhraseDate == nil {
            return true
        }
        return false
    }
}

//MARK: - Prompts
extension UserDefaults {
    static var hasPromptedTouchId: Bool {
        get {
            return defaults.bool(forKey: hasPromptedTouchIdKey)
        }
        set {
            defaults.set(newValue, forKey: hasPromptedTouchIdKey)
        }
    }
}
