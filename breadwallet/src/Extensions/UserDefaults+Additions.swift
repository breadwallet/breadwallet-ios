//
//  UserDefaults+Additions.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-04-04.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation

private let defaults = UserDefaults.standard
private let isBiometricsEnabledKey = "istouchidenabled"
private let defaultCurrencyCodeKey = "defaultcurrency"
private let hasAquiredShareDataPermissionKey = "has_acquired_permission"
private let legacyWalletNeedsBackupKey = "WALLET_NEEDS_BACKUP"
private let writePaperPhraseDateKey = "writepaperphrasedatekey"
private let hasPromptedBiometricsKey = "haspromptedtouched"
private let hasPromptedForEmailKey = "hasPromptedForEmail"
private let hasSubscribedToEmailUpdatesKey = "hasSubscribedToEmailUpdates"
private let isBtcSwappedKey = "isBtcSwappedKey"
private let maxDigitsKey = "SETTINGS_MAX_DIGITS"
private let pushTokenKey = "pushTokenKey"
private let currentRateKey = "currentRateKey"
private let customNodeIPKey = "customNodeIPKey"
private let customNodePortKey = "customNodePortKey"
private let hasPromptedShareDataKey = "hasPromptedShareDataKey"
private let hasCompletedKYC = "hasCompletedKYCKey"
private let hasAgreedToCrowdsaleTermsKey = "hasAgreedToCrowdsaleTermsKey"
private let feesKey = "feesKey"
private let selectedCurrencyCodeKey = "selectedCurrencyCodeKey"
private let mostRecentSelectedCurrencyCodeKey = "mostRecentSelectedCurrencyCodeKey"
private let hasSetSelectedCurrencyKey = "hasSetSelectedCurrencyKey"
private let hasBchConnectedKey = "hasBchConnectedKey"
private let rescanStateKeyPrefix = "lastRescan" // append uppercased currency code for key

extension UserDefaults {

    static var isBiometricsEnabled: Bool {
        get {
            guard defaults.object(forKey: isBiometricsEnabledKey) != nil else {
                return false
            }
            return defaults.bool(forKey: isBiometricsEnabledKey)
        }
        set { defaults.set(newValue, forKey: isBiometricsEnabledKey) }
    }

    static var defaultCurrencyCode: String {
        get {
            guard defaults.object(forKey: defaultCurrencyCodeKey) != nil else {
                return Locale.current.currencyCode ?? "USD"
            }
            return defaults.string(forKey: defaultCurrencyCodeKey)!
        }
        set { defaults.set(newValue, forKey: defaultCurrencyCodeKey) }
    }

    static var hasAquiredShareDataPermission: Bool {
        get {
            //If user's haven't set this key, default to true
            if defaults.object(forKey: hasAquiredShareDataPermissionKey) == nil {
                return true
            }
            return defaults.bool(forKey: hasAquiredShareDataPermissionKey)
        }
        set { defaults.set(newValue, forKey: hasAquiredShareDataPermissionKey) }
    }

    static var isBtcSwapped: Bool {
        get { return defaults.bool(forKey: isBtcSwappedKey)
        }
        set { defaults.set(newValue, forKey: isBtcSwappedKey) }
    }

    //
    // 2 - bits
    // 5 - mBTC
    // 8 - BTC
    //
    static var maxDigits: Int {
        get {
            guard defaults.object(forKey: maxDigitsKey) != nil else {
                return Currencies.btc.commonUnit.decimals
            }
            let maxDigits = defaults.integer(forKey: maxDigitsKey)
            if maxDigits == 5 {
                return 8 //Convert mBTC to BTC
            } else {
                return maxDigits
            }
        }
        set { defaults.set(newValue, forKey: maxDigitsKey) }
    }

    static var pushToken: Data? {
        get {
            guard defaults.object(forKey: pushTokenKey) != nil else {
                return nil
            }
            return defaults.data(forKey: pushTokenKey)
        }
        set { defaults.set(newValue, forKey: pushTokenKey) }
    }

    static func currentRate(forCode: String) -> Rate? {
        guard let data = defaults.object(forKey: currentRateKey + forCode.uppercased()) as? [String: Any] else {
            return nil
        }
        return Rate(dictionary: data)
    }

    static func currentRateData(forCode: String) -> [String: Any]? {
        guard let data = defaults.object(forKey: currentRateKey + forCode.uppercased()) as? [String: Any] else {
            return nil
        }
        return data
    }

    static func setCurrentRateData(newValue: [String: Any], forCode: String) {
        defaults.set(newValue, forKey: currentRateKey + forCode.uppercased())
    }

    static var customNodeIP: Int? {
        get {
            guard defaults.object(forKey: customNodeIPKey) != nil else { return nil }
            return defaults.integer(forKey: customNodeIPKey)
        }
        set { defaults.set(newValue, forKey: customNodeIPKey) }
    }

    static var customNodePort: Int? {
        get {
            guard defaults.object(forKey: customNodePortKey) != nil else { return nil }
            return defaults.integer(forKey: customNodePortKey)
        }
        set { defaults.set(newValue, forKey: customNodePortKey) }
    }

    static var hasPromptedShareData: Bool {
        get { return defaults.bool(forKey: hasPromptedBiometricsKey) }
        set { defaults.set(newValue, forKey: hasPromptedBiometricsKey) }
    }

    // TODO:BCH not used, remove?
    static var fees: Fees? {
        //Returns nil if feeCacheTimeout exceeded
        get {
            if let feeData = defaults.data(forKey: feesKey), let fees = try? JSONDecoder().decode(Fees.self, from: feeData){
                return (Date().timeIntervalSince1970 - fees.timestamp) <= C.feeCacheTimeout ? fees : nil
            } else {
                return nil
            }
        }
        set {
            if let fees = newValue, let data = try? JSONEncoder().encode(fees){
                defaults.set(data, forKey: feesKey)
            }
        }
    }
    
    static func rescanState(for currency: CurrencyDef) -> RescanState? {
        let key = rescanStateKeyPrefix + currency.code.uppercased()
        guard let data = defaults.object(forKey: key) as? Data else { return nil }
        return try? PropertyListDecoder().decode(RescanState.self, from: data)
    }
    
    static func setRescanState(for currency: CurrencyDef, to state: RescanState) {
        let key = rescanStateKeyPrefix + currency.code.uppercased()
        defaults.set(try? PropertyListEncoder().encode(state), forKey: key)
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
        get { return defaults.object(forKey: writePaperPhraseDateKey) as! Date? }
        set { defaults.set(newValue, forKey: writePaperPhraseDateKey) }
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
    static var hasPromptedBiometrics: Bool {
        get { return defaults.bool(forKey: hasPromptedBiometricsKey) }
        set { defaults.set(newValue, forKey: hasPromptedBiometricsKey) }
    }
    
    static var hasPromptedForEmail: Bool {
        get { return defaults.bool(forKey: hasPromptedForEmailKey ) }
        set { defaults.set(newValue, forKey: hasPromptedForEmailKey ) }
    }
    
    static var hasSubscribedToEmailUpdates: Bool {
        get { return defaults.bool(forKey: hasSubscribedToEmailUpdatesKey ) }
        set { defaults.set(newValue, forKey: hasSubscribedToEmailUpdatesKey ) }
    }
}

//MARK: - KYC
extension UserDefaults {
    static func hasCompletedKYC(forContractAddress: String) -> Bool {
        return defaults.bool(forKey: "\(hasCompletedKYC)\(forContractAddress)")
    }

    static func setHasCompletedKYC(_ hasCompleted: Bool, contractAddress: String) {
        defaults.set(hasCompleted, forKey: "\(hasCompletedKYC)\(contractAddress)")
    }

    static var hasAgreedToCrowdsaleTerms: Bool {
        get { return defaults.bool(forKey: hasAgreedToCrowdsaleTermsKey) }
        set { defaults.set(newValue, forKey: hasAgreedToCrowdsaleTermsKey) }
    }
}

//MARK: - State Restoration
extension UserDefaults {
    static var selectedCurrencyCode: String? {
        get {
            if UserDefaults.hasSetSelectedCurrency {
                return defaults.string(forKey: selectedCurrencyCodeKey)
            } else {
                return Currencies.btc.code
            }
        }
        set {
            UserDefaults.hasSetSelectedCurrency = true
            defaults.setValue(newValue, forKey: selectedCurrencyCodeKey)
        }
    }

    static var hasSetSelectedCurrency: Bool {
        get { return defaults.bool(forKey: hasSetSelectedCurrencyKey) }
        set { defaults.setValue(newValue, forKey: hasSetSelectedCurrencyKey) }
    }

    static var mostRecentSelectedCurrencyCode: String {
        get {
            return defaults.string(forKey: mostRecentSelectedCurrencyCodeKey) ?? Currencies.btc.code
        }
        set {
            defaults.setValue(newValue, forKey: mostRecentSelectedCurrencyCodeKey)
        }
    }

    static var hasBchConnected: Bool {
        get { return defaults.bool(forKey: hasBchConnectedKey) }
        set { defaults.set(newValue, forKey: hasBchConnectedKey) }
    }
}
