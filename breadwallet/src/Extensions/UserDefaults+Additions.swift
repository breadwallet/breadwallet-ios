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
private let defaultCurrencyCodeKey = "defaultcurrency"
private let hasAquiredShareDataPermissionKey = "has_acquired_permission"
private let legacyWalletNeedsBackupKey = "WALLET_NEEDS_BACKUP"
private let writePaperPhraseDateKey = "writepaperphrasedatekey"
private let hasPromptedTouchIdKey = "haspromptedtouched"
private let isBtcSwappedKey = "isBtcSwappedKey"
private let maxDigitsKey = "SETTINGS_MAX_DIGITS"
private let pushTokenKey = "pushTokenKey"
private let currentRateKey = "currentRateKey"
private let canShareDataKey = "canShareDataKey"

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

    static var defaultCurrencyCode: String {
        get {
            guard defaults.object(forKey: defaultCurrencyCodeKey) != nil else {
                return Locale.current.currencyCode ?? "USD"
            }
            return defaults.string(forKey: defaultCurrencyCodeKey)!
        }
        set {
            defaults.set(newValue, forKey: defaultCurrencyCodeKey)
        }
    }

    static var hasAquiredShareDataPermission: Bool {
        get {
            guard defaults.object(forKey: hasAquiredShareDataPermissionKey) != nil else {
                return false
            }
            return defaults.bool(forKey: hasAquiredShareDataPermissionKey)
        }
        set {
            defaults.set(newValue, forKey: hasAquiredShareDataPermissionKey)
        }
    }

    static var isBtcSwapped: Bool {
        get {
            return defaults.bool(forKey: isBtcSwappedKey)
        }
        set {
            defaults.set(newValue, forKey: isBtcSwappedKey)
        }
    }

    //
    // 2 - bits
    // 5 - mBTC
    // 8 - BTC
    //
    static var maxDigits: Int {
        get {
            guard defaults.object(forKey: maxDigitsKey) != nil else {
                return 2
            }
            let maxDigits = defaults.integer(forKey: maxDigitsKey)
            if maxDigits == 5 {
                return 8 //Convert mBTC to BTC
            } else {
                return maxDigits
            }
        }
        set {
            defaults.set(newValue, forKey: maxDigitsKey)
        }
    }

    static var pushToken: Data? {
        get {
            guard defaults.object(forKey: pushTokenKey) != nil else {
                return nil
            }
            return defaults.data(forKey: pushTokenKey)
        }
        set {
            defaults.set(newValue, forKey: pushTokenKey)
        }
    }

    static var currentRate: Rate? {
        get {
            guard let data = defaults.object(forKey: currentRateKey) as? [String: Any] else {
                return nil
            }
            return Rate(data: data)
        }
    }

    static var currentRateData: [String: Any]? {
        get {
            guard let data = defaults.object(forKey: currentRateKey) as? [String: Any] else {
                return nil
            }
            return data
        }
        set {
            defaults.set(newValue, forKey: currentRateKey)
        }
    }

    static var canShareData: Bool {
        get {
            return defaults.bool(forKey: canShareDataKey)
        }
        set {
            defaults.set(newValue, forKey: canShareDataKey)
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
        if UserDefaults.writePaperPhraseDate != nil {
            return false
        }
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
