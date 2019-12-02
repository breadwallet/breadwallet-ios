//
//  UserDefaults+Additions.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-04-04.
//  Copyright © 2017-2019 Breadwinner AG. All rights reserved.
//

import Foundation

private let defaults = UserDefaults.standard
private let isBiometricsEnabledKey = "istouchidenabled"
private let isBiometricsEnabledForTransactionsKey = "isbiometricsenabledtx"
private let defaultCurrencyCodeKey = "defaultcurrency"
private let hasAquiredShareDataPermissionKey = "has_acquired_permission"
private let legacyWalletNeedsBackupKey = "WALLET_NEEDS_BACKUP"
private let writePaperPhraseDateKey = "writepaperphrasedatekey"
private let hasPromptedBiometricsKey = "haspromptedtouched"
private let hasPromptedForEmailKey = "hasPromptedForEmail"
private let hasSubscribedToEmailUpdatesKey = "hasSubscribedToEmailUpdates"
private let showFiatAmountsKey = "isBtcSwappedKey" // legacy key name
private let pushTokenKey = "pushTokenKey"
private let currentRateKey = "currentRateKey"
private let customNodeIPKey = "customNodeIPKey"
private let customNodePortKey = "customNodePortKey"
private let hasPromptedShareDataKey = "hasPromptedShareDataKey"
private let hasCompletedKYC = "hasCompletedKYCKey"
private let hasAgreedToCrowdsaleTermsKey = "hasAgreedToCrowdsaleTermsKey"
private let selectedCurrencyCodeKey = "selectedCurrencyCodeKey"
private let mostRecentSelectedCurrencyCodeKey = "mostRecentSelectedSPVCurrencyCodeKey"
private let hasSetSelectedCurrencyKey = "hasSetSelectedCurrencyKey"
private let hasBchConnectedKey = "hasBchConnectedKey"
private let rescanStateKeyPrefix = "lastRescan-" // append uppercased currency code for key
private let hasOptedInSegwitKey = "hasOptedInSegwitKey"
private let hasScannedForTokenBalancesKey = "hasScannedForTokenBalances"
private let debugShouldAutoEnterPinKey = "shouldAutoEnterPIN"
private let debugShouldSuppressPaperKeyPromptKey = "shouldSuppressPaperKeyPrompt"
private let debugShouldShowPaperKeyPreviewKey = "debugShouldShowPaperKeyPreviewKey"
private let debugShowAppRatingPromptOnEnterWalletKey = "debugShowAppRatingPromptOnEnterWalletKey"
private let debugSuppressAppRatingPromptKey = "debugSuppressAppRatingPromptKey"
private let debugConnectionModeOverrideKey = "debugConnectionModeOverrideKey"
private let shouldHideBRDRewardsAnimationKey = "shouldHideBRDRewardsAnimationKey"
private let shouldHideBRDCellHighlightKey = "shouldHideBRDCellHighlightKey"
private let debugBackendHostKey = "debugBackendHostKey"
private let debugWebBundleNameKey = "debugWebBundleNameKey"
private let platformDebugURLKey = "platformDebugURLKey"
private let appLaunchCountKey = "appLaunchCountKey"
private let appLaunchCountAtLastRatingPromptKey = "appLaunchCountAtLastRatingPromptKey"
private let notificationOptInDeferralCountKey = "notificationOptInDeferCountKey"
private let appLaunchesAtLastNotificationDeferralKey = "appLaunchesAtLastNotificationDeferralKey"
private let deviceIdKey = "BR_DEVICE_ID"
private let savedChartHistoryPeriodKey = "savedHistoryPeriodKey"

typealias ResettableBooleanSetting = [String: Bool]
typealias ResettableObjectSetting = String

extension UserDefaults {
    
    // Add any keys here that you want to be able to reset without having
    // to reset the simulator settings.
    static let resettableBooleans: [ResettableBooleanSetting] = [
        [hasPromptedForEmailKey: false],
        [hasSubscribedToEmailUpdatesKey: false],
        [hasPromptedBiometricsKey: false],
        [isBiometricsEnabledKey: false],
        [isBiometricsEnabledForTransactionsKey: false],
        [hasPromptedShareDataKey: false],
        [hasOptedInSegwitKey: false],
        [debugShouldAutoEnterPinKey: false],
        [debugShouldSuppressPaperKeyPromptKey: false],
        [debugShouldShowPaperKeyPreviewKey: false],
        [debugSuppressAppRatingPromptKey: false],
        [debugShowAppRatingPromptOnEnterWalletKey: false],
        [shouldHideBRDCellHighlightKey: false],
        [shouldHideBRDRewardsAnimationKey: false]
    ]
    
    static let resettableObjects: [ResettableObjectSetting] = [
        writePaperPhraseDateKey
    ]
    
    // Called from the Reset User Defaults menu item to allow the resetting of
    // the UserDefaults state for showing/hiding elements, etc.
    static func resetAll() {
        
        for resettableBooelan in resettableBooleans {
            if let key = resettableBooelan.keys.first {
                let defaultValue = resettableBooelan[key]
                defaults.set(defaultValue, forKey: key)
            }
        }
        
        reset(for: Announcement.hasShownKeyPrefix)
        reset(for: NotificationHandler.hasShownInAppNotificationKeyPrefix)

        for resettableObject in resettableObjects {
            defaults.removeObject(forKey: resettableObject)
        }
        
        appLaunchCount = 0
        notificationOptInDeferralCount = 0
        appLaunchesAtLastNotificationDeferral = 0
    }
    
    static func reset(for keysWithPrefix: String) {
        defaults.dictionaryRepresentation().keys.filter({ return $0.hasPrefix(keysWithPrefix) }).forEach { (key) in
            defaults.set(false, forKey: key)
        }
    }
}

extension UserDefaults {

    /// A UUID unique to the installation, generated on first use
    /// Used for BlockchainDB subscription, tx metadata, backend auth
    static var deviceID: String {
        if let s = defaults.string(forKey: deviceIdKey) {
            return s
        }
        let s = UUID().uuidString
        defaults.set(s, forKey: deviceIdKey)
        return s
    }
    
    // Legacy setting for biometrics allowing unlocking the app. This is checked when migrating from
    // UserDefaults to KeyStore for storing the biometrics authorization.
    static var isBiometricsEnabled: Bool {
        guard defaults.object(forKey: isBiometricsEnabledKey) != nil else {
            return false
        }
        return defaults.bool(forKey: isBiometricsEnabledKey)
    }
    
    // Deprecates legacy biometrics setting after migrating the settings to KeyStore.
    static func deprecateLegacyBiometricsSetting() {
        defaults.set(nil, forKey: isBiometricsEnabledKey)
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

    static var showFiatAmounts: Bool {
        get { return defaults.bool(forKey: showFiatAmountsKey)
        }
        set { defaults.set(newValue, forKey: showFiatAmountsKey) }
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

    static var customNodeIP: String? {
        get {
            guard defaults.object(forKey: customNodeIPKey) != nil else { return nil }
            // migrate IPs stored as integer to string format
            if var numericAddress = defaults.object(forKey: customNodeIPKey) as? Int32,
                let buf = addr2ascii(AF_INET, &numericAddress, Int32(MemoryLayout<in_addr_t>.size), nil) {
                    let addressString = String(cString: buf)
                    defaults.set(addressString, forKey: customNodeIPKey)
                    return addressString
            } else {
                return defaults.string(forKey: customNodeIPKey)
            }
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
    
    static func rescanState(for currency: Currency) -> RescanState? {
        let key = rescanStateKeyPrefix + currency.code.uppercased()
        guard let data = defaults.object(forKey: key) as? Data else { return nil }
        return try? PropertyListDecoder().decode(RescanState.self, from: data)
    }
    
    static func setRescanState(for currency: Currency, to state: RescanState) {
        let key = rescanStateKeyPrefix + currency.code.uppercased()
        defaults.set(try? PropertyListEncoder().encode(state), forKey: key)
    }
    
    private static func lastBlockHeightKey(for currency: Currency) -> String {
        return "LastBlockHeightKey-\(currency.code)"
    }
    
    // Returns the stored value for the height of the last block that was successfully sync'd for the given currency.
    static func lastSyncedBlockHeight(for currency: Currency) -> UInt32 {
        return UInt32(UserDefaults.standard.integer(forKey: lastBlockHeightKey(for: currency)))
    }
    
    // Sets the stored value for the height of the last block that was successfully sync'd for the given currency.
    static func setLastSyncedBlockHeight(height: UInt32, for currency: Currency) {
        UserDefaults.standard.set(height, forKey: lastBlockHeightKey(for: currency))
    }
    
    static var hasOptedInSegwit: Bool {
        get {
            return defaults.bool(forKey: hasOptedInSegwitKey)
        }
        set {
            defaults.set(newValue, forKey: hasOptedInSegwitKey)
        }
    }
    
    static var hasScannedForTokenBalances: Bool {
        get {
            return defaults.bool(forKey: hasScannedForTokenBalancesKey)
        }
        set {
            defaults.set(newValue, forKey: hasScannedForTokenBalancesKey)
        }
    }
    
    static var lastChartHistoryPeriod: String? {
        get {
            return defaults.string(forKey: savedChartHistoryPeriodKey)
        }
        set {
            defaults.set(newValue, forKey: savedChartHistoryPeriodKey)
        }
    }
}

// MARK: - Wallet Requires Backup
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
        get { return defaults.object(forKey: writePaperPhraseDateKey) as? Date }
        set { defaults.set(newValue, forKey: writePaperPhraseDateKey) }
    }

    static var writePaperPhraseDateString: String {
        guard let date = writePaperPhraseDate else { return "" }
        let df = DateFormatter()
        df.setLocalizedDateFormatFromTemplate("MMMM d, yyyy")
        return String(format: S.StartPaperPhrase.date, df.string(from: date))
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

// MARK: - Prompts
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

    static var shouldShowBRDRewardsAnimation: Bool {
        // boolean logic is flipped so that 'hide == false' is the default state,
        // whereas the calling code can check whether to show, which has clearer semantics
        // (same logic is employed for 'shouldShowBRDCellHighlight')
        get { return !defaults.bool(forKey: shouldHideBRDRewardsAnimationKey)   }
        set { defaults.set(!newValue, forKey: shouldHideBRDRewardsAnimationKey) }
    }

    static var shouldShowBRDCellHighlight: Bool {
        get { return !defaults.bool(forKey: shouldHideBRDCellHighlightKey)   }
        set { defaults.set(!newValue, forKey: shouldHideBRDCellHighlightKey) }
    }
    
    // Returns the number of times the user has deferred the notifications opt-in decision.
    static var notificationOptInDeferralCount: Int {
        get { return defaults.integer(forKey: notificationOptInDeferralCountKey) }
        set { defaults.set(newValue, forKey: notificationOptInDeferralCountKey) }
    }
    
    // Returns the number of times the user has deferred the notifications opt-in decision.
    static var appLaunchesAtLastNotificationDeferral: Int {
        get { return defaults.integer(forKey: appLaunchesAtLastNotificationDeferralKey) }
        set { defaults.set(newValue, forKey: appLaunchesAtLastNotificationDeferralKey) }
    }
    
    // The count of app-foreground events. This is used in part for determining when to show the app-rating
    // prompt, as well as when to ask the user to opt into push notifications.
    static var appLaunchCount: Int {
        get { return defaults.integer(forKey: appLaunchCountKey ) }
        set { defaults.set(newValue, forKey: appLaunchCountKey )}
    }
    
    // The app launch count the last time the ratings prompt was shown.
    static var appLaunchCountAtLastRatingPrompt: Int {
        get { return UserDefaults.standard.integer(forKey: appLaunchCountAtLastRatingPromptKey ) }
        set { UserDefaults.standard.set(newValue, forKey: appLaunchCountAtLastRatingPromptKey )}
    }

}

// MARK: - State Restoration
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

// Dev Settings
extension UserDefaults {
    
    // Toggles the UserDefaults boolean setting for the given key and returns the new value.
    static func toggleBoolean(key: String) -> Bool {
        let newValue = !defaults.bool(forKey: key)
        defaults.set(newValue, forKey: key)
        return newValue
    }

    static func toggleAutoEnterPIN() -> Bool {
        return toggleBoolean(key: debugShouldAutoEnterPinKey)
    }
    
    static func toggleSuppressPaperKeyPrompt() -> Bool {
        return toggleBoolean(key: debugShouldSuppressPaperKeyPromptKey)
    }
    
    static func togglePaperKeyPreview() -> Bool {
        return toggleBoolean(key: debugShouldShowPaperKeyPreviewKey)
    }
    
    static var debugShouldAutoEnterPIN: Bool {
        
        get {
            // always return false for release builds
            if E.isSimulator || E.isDebug || E.isTestFlight {
                return defaults.bool(forKey: debugShouldAutoEnterPinKey)
            } else {
                return false
            }
        }
        
        set { 
            defaults.setValue(newValue, forKey: debugShouldAutoEnterPinKey)
        }
    }
    
    static var debugShouldSuppressPaperKeyPrompt: Bool {
        
        get {
            // always return false for release builds
            if E.isSimulator || E.isDebug || E.isTestFlight {
                return defaults.bool(forKey: debugShouldSuppressPaperKeyPromptKey)
            } else {
                return false
            }
        }
        
        set {
            defaults.set(newValue, forKey: debugShouldSuppressPaperKeyPromptKey)
        }
    }
    
    static var debugShouldShowPaperKeyPreview: Bool {
        
        get {
            // always return false for release builds
            if E.isSimulator || E.isDebug || E.isTestFlight {
                return defaults.bool(forKey: debugShouldShowPaperKeyPreviewKey)
            } else {
                return false
            }
        }
        
        set {
            defaults.set(newValue, forKey: debugShouldShowPaperKeyPreviewKey)
        }        
    }
    
    // option to always show the app rating prompt when entering a wallet
    static func toggleShowAppRatingPromptOnEnterWallet() -> Bool {
        return toggleBoolean(key: debugShowAppRatingPromptOnEnterWalletKey)
    }

    static var debugShowAppRatingOnEnterWallet: Bool {
        
        get {
            return defaults.bool(forKey: debugShowAppRatingPromptOnEnterWalletKey)
        }
        
        set {
            defaults.set(newValue, forKey: debugShowAppRatingPromptOnEnterWalletKey)
        }
    }
    
    // option to always suppress showing the app rating prompt
    static func toggleSuppressAppRatingPrompt() -> Bool {
        return toggleBoolean(key: debugSuppressAppRatingPromptKey)
    }

    static var debugSuppressAppRatingPrompt: Bool {
        
        get {
            return defaults.bool(forKey: debugSuppressAppRatingPromptKey)
        }
        
        set {
            defaults.set(newValue, forKey: debugSuppressAppRatingPromptKey)
        }
    }

    static var debugBackendHost: String? {
        get {
            return defaults.string(forKey: debugBackendHostKey)
        }

        set {
            defaults.set(newValue, forKey: debugBackendHostKey)
        }
    }

    static var debugWebBundleName: String? {
        get {
            return defaults.string(forKey: debugWebBundleNameKey)
        }

        set {
            defaults.set(newValue, forKey: debugWebBundleNameKey)
        }
    }

    static var platformDebugURL: URL? {
        get {
            return defaults.url(forKey: platformDebugURLKey)
        }

        set {
            defaults.set(newValue, forKey: platformDebugURLKey)
        }
    }
    
    static func cycleConnectionModeOverride() {
        let newValue = defaults.integer(forKey: debugConnectionModeOverrideKey) + 1
        let newMode = WalletManagerModeOverride(rawValue: newValue) ?? .none
        UserDefaults.debugConnectionModeOverride = newMode
    }
    
    static var debugConnectionModeOverride: WalletManagerModeOverride {
        get {
            let value = defaults.integer(forKey: debugConnectionModeOverrideKey)
            return WalletManagerModeOverride(rawValue: value) ?? .none
        }
        
        set {
            defaults.set(newValue.rawValue, forKey: debugConnectionModeOverrideKey)
        }
    }
}
