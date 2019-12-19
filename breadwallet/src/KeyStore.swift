//
//  KeyStore.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2019-01-14.
//  Copyright © 2019 Breadwinner AG.
//

import Foundation
import UIKit
import LocalAuthentication
import BRCrypto
import CloudKit

private var WalletSecAttrService: String {
    if E.isRunningTests { return "com.brd.testnetQA.tests" }
    #if TESTNET
    return "com.brd.testnetQA"
    #elseif INTERNAL
    return "com.brd.internalQA"
    #else
    return "org.voisine.breadwallet"
    #endif
}

enum KeyStoreError: Error {
    case alreadyInitialized
    case keychainError(NSError)
}

enum BiometricsResult {
    case success
    case cancel
    case fallback
    case failure
}

enum AccountError: Error {
    case noAccount
    case disabled
    case invalidSerialization
}

enum APIAuthenticationError: Error {
    case invalidKey
    case invalidClientToken
    case invalidUserCredentials(APIRequestError)
    case tokenGenerationError(Error)
}
typealias APIAuthenticationResult = Result<JWT, APIAuthenticationError>

private struct DefaultsKey {
    public static let pinUnlockTime = "PIN_UNLOCK_TIME"
}

/// Protocol for basic wallet authentication for login / API / public key access
protocol WalletAuthenticator {
    var noWallet: Bool { get }
    var creationTime: Date { get }

    var pinLoginRequired: Bool { get }
    var pinLength: Int { get }
    var walletDisabledUntil: TimeInterval { get }
    var walletIsDisabled: Bool { get }
    var pinAttemptsRemaining: Int { get }
    
    var isBiometricsEnabledForUnlocking: Bool { get set }
    var isBiometricsEnabledForTransactions: Bool { get set }

    func authenticate(withPin: String) -> Bool
    func authenticate(withPhrase: String) -> Bool
    func authenticate(withBiometricsPrompt: String, completion: @escaping (BiometricsResult) -> Void)

    func loadAccount() -> Result<Account, AccountError>
    func createAccount(withPin: String) -> Account?
    func createAccount(withBiometricsPrompt: String, completion: @escaping (Account?) -> Void)

    var apiAuthKey: Key? { get }
    var apiUserAccount: [AnyHashable: Any]? { get set }

    func authenticateWithBlockchainDB(client: AuthenticationClient, completion: @escaping (APIAuthenticationResult) -> Void)

    func buildBitIdKey(url: String, index: Int) -> Key?
}

extension WalletAuthenticator {
    var walletIsDisabled: Bool {
        return walletDisabledUntil > Date().timeIntervalSince1970
    }
}

/// Protocol for signing transactions
protocol TransactionAuthenticator: WalletAuthenticator {
    func signAndSubmit(transfer: BRCrypto.Transfer, wallet: Wallet, withPin: String) -> Bool
    func signAndSubmit(transfer: BRCrypto.Transfer,
                       wallet: Wallet,
                       withBiometricsPrompt: String,
                       completion: @escaping (BiometricsResult) -> Void)
}

/// Protocol for setting and changing the seed and PIN in the keychain
protocol KeyMaster: WalletAuthenticator {
    /// Set initial PIN when no PIN is set
    func setPin(_ newPin: String) -> Bool
    /// Change PIN given old PIN
    func changePin(newPin: String, currentPin: String) -> Bool
    /// Reset to new PIN given seed phrase, or set a new PIN if none is set
    func resetPin(newPin: String, seedPhrase: String) -> Bool

    /// returns the 12 word wallet recovery phrase, given the pin
    func seedPhrase(pin: String) -> String?

    /// recovers an existing wallet using 12 word wallet recovery phrase
    /// will fail if a wallet already exists on the keychain
    func setSeedPhrase(_ phrase: String) -> Account?

    /// creates a new wallet and returns the 12 word wallet recovery phrase
    /// will fail if a wallet already exists on the keychain
    func setRandomSeedPhrase() -> (phrase: String, account: Account)?

    func fetchCreationDate(for recoveredAccount: Account, completion: @escaping (Account) -> Void)

    /// wipes the existing wallet (keys, recovery phrase) from the keychain and the KV store database.
    /// this should only be called through Store.trigger(.wipeWalletNoPrompts)
    func wipeWallet() -> Bool

    /// Returns true if all words in the phrase are from a BIP39 word list and the checksum is valid
    func isSeedPhraseValid(_ phrase: String) -> Bool
    /// Returns true if the word belongs to any supported BIP39 word lists
    func isSeedWordValid(_ word: String) -> Bool
}

/// The KeyStore manages keychain access by implementing the access protocols
/// There can be only one instance (singleton) but this instance is not globally accessible
class KeyStore {

    static private var instance: KeyStore?

    static private var failedPins = [String]()

    private let maxPinAttemptsBeforeDisable: Int64 = 3
    private let maxPinAttemptsBeforeWipe: Int64 = 8
    private let defaultPinLength = 6

    private var allBip39WordLists: [[NSString]] = []
    private var allBip39Words: Set<String> = []

    /// Creates the singleton instance of the KeyStore and returns it
    static func create() throws -> KeyStore {
        guard KeyStore.instance == nil else {
            throw KeyStoreError.alreadyInitialized
        }

        if try keychainItem(key: KeychainKey.seed) as Data? != nil { // upgrade from old keychain accessibility scheme
            print("[KEYSTORE] upgrading to authenticated keychain scheme")
            let seedPhrase: String? = try keychainItem(key: KeychainKey.mnemonic)
            try setKeychainItem(key: KeychainKey.mnemonic, item: seedPhrase, authenticated: true)
            try setKeychainItem(key: KeychainKey.seed, item: nil as Data?)
        }

        instance = try KeyStore()
        return instance!
    }

    private init() throws {
        // load BIP39 word lists
        Bundle.main.localizations.forEach { lang in
            if let path = Bundle.main.path(forResource: "BIP39Words", ofType: "plist", inDirectory: nil, forLocalization: lang) {
                if let words = NSArray(contentsOfFile: path) as? [NSString] {
                    allBip39WordLists.append(words)
                    allBip39Words.formUnion(words.map { $0 as String })
                }
            }
        }

        // pre-fetch client token
        if !E.isRunningTests, try keychainItem(key: KeychainKey.bdbClientToken) as String? == nil {
            KeyStore.fetchClientToken { _ in }
        }
    }
    
    /// Returns true if old masterPubKey record is in the keychain and removes them
    /// to prepare for migration to stored Account
    private func migrationNeeded() -> Bool {
        do {
            if try keychainItem(key: KeychainKey.masterPubKey) as Data? != nil {
                return true
            }
        } catch let error {
            assertionFailure("keychain error: \(error.localizedDescription)")
        }
        return false
    }
    
    /// Removes deprecated keys from the keychain
    private func clearDeprecatedKeys() {
        guard case .success = loadAccount() else { return assertionFailure() }
        
        do {
            if try keychainItem(key: KeychainKey.masterPubKey) as Data? != nil {
                try setKeychainItem(key: KeychainKey.masterPubKey, item: nil as Data?)
            }
            if try keychainItem(key: KeychainKey.ethPrivKey) as Data? != nil {
                try setKeychainItem(key: KeychainKey.ethPrivKey, item: nil as Data?)
            }
        } catch let error {
            assertionFailure("keychain error: \(error.localizedDescription)")
        }
    }
}

// MARK: - WalletAuthenticator

extension KeyStore: WalletAuthenticator {

    /// true if keychain is available and we know that no wallet exists on it
    var noWallet: Bool {
        do {
            if try keychainItem(key: KeychainKey.systemAccount) as Data? != nil { return false }
            if try keychainItem(key: KeychainKey.masterPubKey) as Data? != nil { return false }
            if try keychainItem(key: KeychainKey.seed) as Data? != nil { return false } // check for old keychain scheme
            return true
        } catch { return false }
    }

    var creationTime: Date {
        var creationTime = C.bip39CreationTime
        if let creationTimeData: Data = try? keychainItem(key: KeychainKey.creationTime),
            creationTimeData.count == MemoryLayout<TimeInterval>.stride {
            creationTimeData.withUnsafeBytes { creationTime = $0.load(as: TimeInterval.self) }
        }
        return Date(timeIntervalSinceReferenceDate: creationTime)
    }
    
    private var serializedAccountData: Data? {
        return try? keychainItem(key: KeychainKey.systemAccount)
    }
    
    // MARK: biometrics authentication
    
    /// Returns whether the user can unlock the BRD app with biometrics (Touch ID or Face ID) rather than
    /// requiring PIN entry.
    var isBiometricsEnabledForUnlocking: Bool {
        get {
            var enabled = false
            
            do {
                if let value: Int64 = try keychainItem(key: KeychainKey.biometricsUnlocking) {
                    enabled = (value == Int64(1))
                } else {
                    // One-time migration check for the legacy setting since there was no value in the keystore.
                    if UserDefaults.isBiometricsEnabled {
                        UserDefaults.deprecateLegacyBiometricsSetting()
                        try setKeychainItem(key: KeychainKey.biometricsUnlocking, item: Int64(1))
                        enabled = true
                    } else {
                        try setKeychainItem(key: KeychainKey.biometricsUnlocking, item: Int64(0))
                    }
                }
            } catch {}
            
            return enabled
        }
        
        set {
            do {
                try setKeychainItem(key: KeychainKey.biometricsUnlocking, item: newValue ? Int64(1) : Int64(0))
            } catch {}
        }
    }
    
    /// Returns whether the user can authorize transactions with biometrics (Touch ID or Face ID) rather
    /// than requiring PIN entry.
    var isBiometricsEnabledForTransactions: Bool {
        get {
            var enabled = false
            
            do {
                let value: Int64 = try keychainItem(key: KeychainKey.biometricsTransactions) ?? Int64(0)
                enabled = (value == Int64(1))
            } catch {}
            
            return enabled
        }
        
        set {
            do {
                try setKeychainItem(key: KeychainKey.biometricsTransactions, item: newValue ? Int64(1) : Int64(0))
            } catch {}
        }
    }

    // MARK: - Keys

    /// key used for authenticated API calls
    var apiAuthKey: Key? {
        return autoreleasepool {
            do {
                if let apiKeyString = try keychainItem(key: KeychainKey.apiAuthKey) as String?,
                    !apiKeyString.isEmpty,
                    let apiKey = Key.createFromString(asPrivate: apiKeyString) {
                    return apiKey
                }
                guard let phrase: String = try keychainItem(key: KeychainKey.mnemonic),
                    let words = Words.wordList?.map({ $0 as String }),
                    let apiKey = Key.createForBIP32ApiAuth(phrase: phrase, words: words) else { return nil }
                try setKeychainItem(key: KeychainKey.apiAuthKey, item: apiKey.encodeAsPrivate)
                return apiKey
            } catch let error {
                print("[KEYSTORE] apiAuthKey error: \(error)")
                return nil
            }
        }
    }

    /// API access credentials
    var apiUserAccount: [AnyHashable: Any]? {
        get {
            do {
                return try keychainItem(key: KeychainKey.apiUserAccount)
            } catch { return nil }
        }

        set (value) {
            do {
                try setKeychainItem(key: KeychainKey.apiUserAccount, item: value)
            } catch { }
        }
    }
    
    // MARK: - BlockchainDB Authentication

    func authenticateWithBlockchainDB(client: AuthenticationClient, completion: @escaping (APIAuthenticationResult) -> Void) {
        if let jwt = bdbAuthToken, !jwt.isExpired {
            return completion(.success(jwt))
        }
        print("[KEYSTORE] generating new BDB JWT...")
        generateTokenForBlockchainDB(client: client, completion: completion)
    }

    /// Generate a new JWT access token and store it in the keychain.
    private func generateTokenForBlockchainDB(client: AuthenticationClient, completion: @escaping (APIAuthenticationResult) -> Void) {
        guard let key = apiAuthKey else { assertionFailure(); return completion(.failure(.invalidKey)) }
        getAuthCredentials(client: client, key: key) { authUserResult in
            let jwtResult = authUserResult.flatMap { authUser -> APIAuthenticationResult in
                print("[KEYSTORE] BDB user id: \(authUser.userId)")
                return client.generateToken(for: authUser, key: key)
                    .mapError { APIAuthenticationError.tokenGenerationError($0) }
            }
            if case .success(let jwt) = jwtResult {
                self.bdbAuthToken = jwt  // save in keychain
            }
            completion(jwtResult)
        }
    }

    /// Get user authentication credentials from keychain if available.
    /// Fetch new credentials from server and store in keychain if not available.
    private func getAuthCredentials(client: AuthenticationClient, key: Key, completion: @escaping (Result<AuthUserCredentials, APIAuthenticationError>) -> Void) {
        if let authUser = bdbAuthUser {
            return completion(.success(authUser))
        }
        // handshake with server
        getClientToken { clientToken in
            guard let clientToken = clientToken else { return completion(.failure(.invalidClientToken)) }
            print("[KEYSTORE] fetching user credentials...")
            client.authenticate(apiKey: key,
                                clientToken: clientToken,
                                deviceId: UserDefaults.deviceID) { result in
                                    let result = result.mapError({ APIAuthenticationError.invalidUserCredentials($0) })
                                    if case .success(let authUser) = result {
                                        self.bdbAuthUser = authUser // save in keychain
                                    }
                                    completion(result)
            }
        }
    }

    private var bdbAuthUser: AuthUserCredentials? {
        get {
            guard let userData: Data = try? keychainItem(key: KeychainKey.bdbAuthUser) else { return nil }
            return try? JSONDecoder().decode(AuthUserCredentials.self, from: userData)
        }

        set {
            do {
                let userData: Data? = try newValue.map { try JSONEncoder().encode($0) }
                try setKeychainItem(key: KeychainKey.bdbAuthUser, item: userData)
            } catch let e {
                print("[KEYSTORE] keychain error: \(e.localizedDescription)")
                assertionFailure()
            }
        }
    }

    private var bdbAuthToken: JWT? {
        get {
            do {
                guard let tokenData: Data = try keychainItem(key: KeychainKey.bdbAuthToken) else { return nil }
                return try JSONDecoder().decode(JWT.self, from: tokenData)
            } catch let e {
                print("[KEYSTORE] keychain error: \(e.localizedDescription)")
                assertionFailure()
                return nil
            }
        }

        set {
            do {
                let tokenData: Data? = try newValue.map { try JSONEncoder().encode($0) }
                try setKeychainItem(key: KeychainKey.bdbAuthToken, item: tokenData)
            } catch let e {
                print("[KEYSTORE] keychain error: \(e.localizedDescription)")
                assertionFailure()
            }
        }
    }

    private func getClientToken(completion: @escaping (String?) -> Void) {
        // fetch from keychain
        do {
            if let token: String = try keychainItem(key: KeychainKey.bdbClientToken) {
                return completion(token)
            }
        } catch let error {
            print("[KEYSTORE] keychain error: \(error.localizedDescription)")
            assertionFailure()
        }
        KeyStore.fetchClientToken(completion: completion)
    }

    private static func fetchClientToken(completion: @escaping (String?) -> Void) {
        // fetch from CloudKit and store in keychain
        CKContainer.default().publicCloudDatabase.fetch(withRecordID: CKRecord.ID(recordName: C.bdbClientTokenRecordId)) { record, error in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let token = record?.value(forKey: "token") as? String else {
                    print("[KEYSTORE] CloudKit error: \(error?.localizedDescription ?? "none")")
                    return completion(nil)
                }
                print("[KEYSTORE] retreived client token from CloudKit")
                do {
                    try setKeychainItem(key: KeychainKey.bdbClientToken, item: token)
                } catch let error {
                    print("[KEYSTORE] keychain error: \(error.localizedDescription)")
                    assertionFailure()
                }
                completion(token)
            }
        }
    }

    // MARK: - BitID

    func buildBitIdKey(url: String, index: Int) -> Key? {
        return autoreleasepool {
            do {
                guard let phrase: String = try keychainItem(key: KeychainKey.mnemonic),
                    let words = Words.wordList?.map({ $0 as String }) else { return nil }
                return Key.createForBIP32BitID(phrase: phrase,
                                               index: index,
                                               uri: url,
                                               words: words)
            } catch {
                return nil
            }
        }
    }
    
    // MARK: - Login

    /// Login with pin should be required if the pin hasn't been used within a week
    var pinLoginRequired: Bool {
        let pinUnlockTime = UserDefaults.standard.double(forKey: DefaultsKey.pinUnlockTime)
        let now = Date.timeIntervalSinceReferenceDate
        let secondsInWeek = 60.0*60.0*24.0*7.0
        return now - pinUnlockTime > secondsInWeek
    }

    /// number of unique failed pin attempts remaining before wallet is wiped
    var pinAttemptsRemaining: Int {
        do {
            let failCount: Int64 = try keychainItem(key: KeychainKey.pinFailCount) ?? 0
            return Int(maxPinAttemptsBeforeWipe - failCount)
        } catch { return -1 }
    }

    var walletIsDisabled: Bool {
        let now = Date().timeIntervalSince1970
        return walletDisabledUntil > now
    }

    /// after 3 or more failed pin attempts, authentication is disabled until this time (interval since reference date)
    var walletDisabledUntil: TimeInterval {
        do {
            let failCount: Int64 = try keychainItem(key: KeychainKey.pinFailCount) ?? 0
            guard failCount >= maxPinAttemptsBeforeDisable else { return 0 }
            let failTime: Int64 = try keychainItem(key: KeychainKey.pinFailTime) ?? 0
            return Double(failTime) + pow(6, Double(failCount - maxPinAttemptsBeforeDisable)) * 60
        } catch let error {
            assert(false, "Error: \(error)")
            return 0
        }
    }

    //Can be expensive...result should be cached
    var pinLength: Int {
        do {
            if let pin: String = try keychainItem(key: KeychainKey.pin) {
                return pin.utf8.count
            } else {
                return defaultPinLength
            }
        } catch let error {
            print("Pin keychain error: \(error)")
            return defaultPinLength
        }
    }

    /// returns true if pin is correct and wallet is not disabled.
    ///   - unique failed attempts are recorded
    ///   - on the 3rd failed attempt authentication is disabled for 1 minute
    ///   - attempts made during the disabled period do not count as failures
    ///   - on subsequent (4th-7tn) wrong pin attempts, authentication is disabled for 6, 36, 216, 1296 minutes respectively
    ///   - on the 8th failed attempt (over 24h elapsed) the stored wallet keys are wiped
    func authenticate(withPin pin: String) -> Bool {
        do {
            let secureTime = Date().timeIntervalSince1970 // TODO: XXX use secure time from https request
            var failCount: Int64 = try keychainItem(key: KeychainKey.pinFailCount) ?? 0

            if failCount >= maxPinAttemptsBeforeDisable {
                let failTime: Int64 = try keychainItem(key: KeychainKey.pinFailTime) ?? 0

                if secureTime < Double(failTime) + pow(6, Double(failCount - maxPinAttemptsBeforeDisable)) * 60 { // locked out
                    return false
                }
            }

            if !KeyStore.failedPins.contains(pin) { // count unique attempts before checking success
                failCount += 1
                try setKeychainItem(key: KeychainKey.pinFailCount, item: Int64(failCount))
            }

            if try pin == keychainItem(key: KeychainKey.pin) { // successful pin attempt
                try authenticationSuccess()
                return true
            } else if !KeyStore.failedPins.contains(pin) { // unique failed attempt
                KeyStore.failedPins.append(pin)

                if failCount >= 8 { // wipe wallet after 8 failed pin attempts and 24+ hours of lockout
                    Store.trigger(name: .wipeWalletNoPrompt)
                    return false
                }
                let pinFailTime: Int64 = try keychainItem(key: KeychainKey.pinFailTime) ?? 0
                if secureTime > Double(pinFailTime) {
                    try setKeychainItem(key: KeychainKey.pinFailTime, item: Int64(secureTime))
                }
            }

            return false
        } catch let error {
            assert(false, "Error: \(error)")
            return false
        }
    }
    
    /// returns true if phrase is correct
    func authenticate(withPhrase phrase: String) -> Bool {
        guard let nfkdPhrase = CFStringCreateMutableCopy(secureAllocator, 0, phrase as CFString)
            else { return false }
        CFStringNormalize(nfkdPhrase, .KD)
        guard let existingAccountData = serializedAccountData,
            let account = Account.createFrom(phrase: nfkdPhrase as String,
                                             timestamp: creationTime,
                                             uids: UserDefaults.deviceID) else { return false }
        
        // validates the account generated from the input phrase matches the stored account (public key)
        return account.validate(serialization: existingAccountData)
    }

    private func authenticationSuccess() throws {
        KeyStore.failedPins.removeAll()
        UserDefaults.standard.set(Date.timeIntervalSinceReferenceDate, forKey: DefaultsKey.pinUnlockTime)
        try setKeychainItem(key: KeychainKey.pinFailTime, item: Int64(0))
        try setKeychainItem(key: KeychainKey.pinFailCount, item: Int64(0))
    }

    func authenticate(withBiometricsPrompt prompt: String, completion: @escaping (BiometricsResult) -> Void) {
        authenticate(withBiometricsPrompt: prompt, context: LAContext(), completion: completion)
    }

    /// show biometric dialog and call completion block with success or failure
    /// optionally pass an LAContext to use (for test stub usage)
    func authenticate(withBiometricsPrompt biometricsPrompt: String,
                      context: LAContext = LAContext(),
                      completion: @escaping (BiometricsResult) -> Void) {
        let policy = LAPolicy.deviceOwnerAuthenticationWithBiometrics
        context.evaluatePolicy(policy, localizedReason: biometricsPrompt, reply: { success, error in
            DispatchQueue.main.async {
                if success { return completion(.success) }
                guard let error = error else { return completion(.failure) }
                if error._code == Int(kLAErrorUserCancel) {
                    return completion(.cancel)
                } else if error._code == Int(kLAErrorUserFallback) {
                    return completion(.fallback)
                }
                completion(.failure)
            }
        })
    }
    
    /// Creates an Account using the serialized Account data in the keychain.
    func loadAccount() -> Result<Account, AccountError> {
        guard !walletIsDisabled else { return .failure(.disabled) }
        guard let accountData = serializedAccountData else {
            if migrationNeeded() {
                // trigger auth and creation of new Account
                print("[KEYSTORE] migrating to serialized Account")
                return .failure(.invalidSerialization)
            } else {
                return .failure(.noAccount)
            }
        }
        guard let account = Account.createFrom(serialization: accountData, uids: UserDefaults.deviceID) else {
            // serialization is outdated and must be recreated
            print("[KEYSTORE] invalid account serialization")
            return .failure(.invalidSerialization)
        }
        return .success(account)
    }
    
    /// Creates a new Account using the paper key and saves it to the keychain.
    /// This method should only be called after successful authentication.
    private func createAccountFromSeed() -> Account? {
        guard let seedPhrase: String = try? keychainItem(key: KeychainKey.mnemonic),
            let account = Account.createFrom(phrase: seedPhrase,
                                             timestamp: creationTime,
                                             uids: UserDefaults.deviceID) else { assertionFailure(); return nil }
        do {
            try setKeychainItem(key: KeychainKey.systemAccount, item: account.serialize)
            clearDeprecatedKeys()
        } catch let error {
            assertionFailure("keychain write error: \(error.localizedDescription)")
            return nil
        }
        return account
    }

    func createAccount(withPin pin: String) -> Account? {
        return authenticate(withPin: pin) ? createAccountFromSeed() : nil
    }

    func createAccount(withBiometricsPrompt prompt: String, completion: @escaping (Account?) -> Void) {
        authenticate(withBiometricsPrompt: prompt) { result in
            if result == .success {
                completion(self.createAccountFromSeed())
            } else {
                completion(nil)
            }
        }
    }
}

// MARK: - TransactionAuthenticator

extension KeyStore: TransactionAuthenticator {

    func signAndSubmit(transfer: BRCrypto.Transfer, wallet: Wallet, withPin pin: String) -> Bool {
        guard authenticate(withPin: pin) else { return false }
        return signAndSubmit(transfer: transfer, wallet: wallet)
    }
    
    func signAndSubmit(transfer: BRCrypto.Transfer,
                       wallet: Wallet,
                       withBiometricsPrompt biometricsPrompt: String,
                       completion: @escaping (BiometricsResult) -> Void) {
        guard self.isBiometricsEnabledForTransactions else {
            return completion(.failure)
        }
        Store.perform(action: BiometricsActions.SetIsPrompting(true))
        authenticate(withBiometricsPrompt: biometricsPrompt) { result in
            Store.perform(action: BiometricsActions.SetIsPrompting(false))
            guard result == .success else { return completion(result) }
            completion(self.signAndSubmit(transfer: transfer, wallet: wallet) ? .success : .failure)
        }
    }
    
    private func signAndSubmit(transfer: BRCrypto.Transfer, wallet: Wallet) -> Bool {
        return autoreleasepool {
            do {
                guard let phrase: String = try keychainItem(key: KeychainKey.mnemonic) else { return false }
                wallet.manager.submit(transfer: transfer, paperKey: phrase)
                return true
            } catch { return false }
        }
    }
}

// MARK: - KeyMaster

extension KeyStore: KeyMaster {

    // MARK: Seed

    /// the 12 word wallet recovery phrase
    func seedPhrase(pin: String) -> String? {
        guard authenticate(withPin: pin) else { return nil }

        do {
            return try keychainItem(key: KeychainKey.mnemonic)
        } catch { return nil }
    }

    /// recover an existing wallet using 12 word wallet recovery phrase
    /// will fail if a wallet seed already exists on the keychain
    func setSeedPhrase(_ phrase: String) -> Account? {
        guard noWallet, isSeedPhraseValid(phrase) else { return nil }

        do {
            guard let nfkdPhrase = CFStringCreateMutableCopy(secureAllocator, 0, phrase as CFString)
                else { return nil }
            CFStringNormalize(nfkdPhrase, .KD)
            guard let account = Account.createFrom(phrase: nfkdPhrase as String,
                                                   timestamp: creationTime,
                                                   uids: UserDefaults.deviceID) else { return nil }
            try setKeychainItem(key: KeychainKey.mnemonic, item: nfkdPhrase as String?, authenticated: true)
            try setKeychainItem(key: KeychainKey.systemAccount, item: account.serialize)
            return account
        } catch { return nil }
    }

    /// create a new wallet and return the 12 word wallet recovery phrase and Account
    /// will fail if a wallet seed already exists on the keychain or a PIN is not set
    func setRandomSeedPhrase() -> (phrase: String, account: Account)? {
        do {
            guard noWallet, try keychainItem(key: KeychainKey.pin) as String? != nil,
                let words = Words.wordList?.map({ $0 as String }) else { return nil }
            
            // wrapping in an autorelease pool ensures sensitive memory is wiped and released immediately
            return try autoreleasepool {
                guard let (phrase, creationDate) = Account.generatePhrase(words: words) else { return nil }
                // we store the wallet creation time in the keychain because keychain data persists even when app is deleted. this must be set before the account is created.
                let creationTimeInterval = creationDate.timeIntervalSinceReferenceDate
                try setKeychainItem(key: KeychainKey.creationTime,
                                    item: [creationTimeInterval].withUnsafeBufferPointer { Data(buffer: $0) })
                guard let account = setSeedPhrase(phrase) else { return nil }
                return (phrase, account)
            }
        } catch { return nil }
    }

    /// connects to the backend with the recovered account to fetch the original creation date from the KV-store.
    /// if found, a new Account is created with the given seed phrase and retrieved creation date.
    /// otherwise the original Account is returned.
    func fetchCreationDate(for recoveredAccount: Account, completion: @escaping (Account) -> Void) {
        assert(!Backend.isConnected)
        do {
            guard try keychainItem(key: KeychainKey.pin) as String? == nil else { preconditionFailure() }
            Backend.connect(authenticator: self)
            guard let kv = Backend.kvStore else { return completion(recoveredAccount) }

            try kv.syncKey(WalletInfo.key) { error in
                guard error == nil, let walletInfo = WalletInfo(kvStore: kv) else {
                    print("[KEY] account timestamp not found in KV-store")
                    return completion(recoveredAccount)
                }
                guard walletInfo.creationDate > recoveredAccount.timestamp else {
                    print("[KEY] account timestamp in KV-store is invalid: \(walletInfo.creationDate)")
                    return completion(recoveredAccount)
                }
                do {
                    guard let phrase: String = try keychainItem(key: KeychainKey.mnemonic),
                        let newAccount = Account.createFrom(phrase: phrase,
                                                            timestamp: walletInfo.creationDate,
                                                            uids: UserDefaults.deviceID) else { return completion(recoveredAccount) }

                    print("[KEY] restored account timestamp from KV-store: \(walletInfo.creationDate)")
                    try setKeychainItem(key: KeychainKey.systemAccount, item: newAccount.serialize)
                    let creationTimeInterval = walletInfo.creationDate.timeIntervalSinceReferenceDate
                    try setKeychainItem(key: KeychainKey.creationTime,
                                        item: [creationTimeInterval].withUnsafeBufferPointer { Data(buffer: $0) })
                    completion(newAccount)
                } catch { return completion(recoveredAccount) }
            }
        } catch { return completion(recoveredAccount) }
    }

    // MARK: PIN

    /// change wallet authentication pin
    func changePin(newPin: String, currentPin: String) -> Bool {
        guard authenticate(withPin: currentPin) else { return false }
        do {
            DispatchQueue.main.async {
                Store.perform(action: PinLength.Set(newPin.utf8.count))
            }
            try setKeychainItem(key: KeychainKey.pin, item: newPin)
            return true
        } catch { return false }
    }

    /// set new wallet authentication pin
    /// returns false if a pin is already set
    func setPin(_ newPin: String) -> Bool {
        do {
            guard try keychainItem(key: KeychainKey.pin) as String? == nil else { assert(E.isRunningTests); return false }

            DispatchQueue.main.async {
                Store.perform(action: PinLength.Set(newPin.utf8.count))
            }
            try setKeychainItem(key: KeychainKey.pin, item: newPin)
            try authenticationSuccess()
            return true
        } catch let error {
            print("[KEY] error setting pin: \(error.localizedDescription) ")
            return false
        }
    }

    /// set/overwrite wallet authentication pin using the wallet recovery phrase
    /// returns false if seed phrase authentication fails
    func resetPin(newPin: String, seedPhrase: String) -> Bool {
        do {
            guard authenticate(withPhrase: seedPhrase) else { return false }

            DispatchQueue.main.async {
                Store.perform(action: PinLength.Set(newPin.utf8.count))
            }
            try setKeychainItem(key: KeychainKey.pin, item: newPin)
            try authenticationSuccess()
            return true
        } catch {
            return false
        }
    }

    // MARK: Wipe

    /// wipe the existing wallet from the keychain
    /// This shouldn't be called directly. Instead use store.trigger(name: .wipeWalletNoPrompts)
    /// Using the trigger will ensure the correct UI gets displayed
    func wipeWallet() -> Bool {
        do {
            print("[KEYSTORE] wiping")
            if let bundleId = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: bundleId)
            }
            assert(Backend.kvStore != nil || E.isRunningTests)
            try Backend.kvStore?.rmdb()
            try? FileManager.default.removeItem(at: BRReplicatedKVStore.dbPath)
            try setKeychainItem(key: KeychainKey.systemAccount, item: nil as Data?)
            try setKeychainItem(key: KeychainKey.apiAuthKey, item: nil as String?)
            try setKeychainItem(key: KeychainKey.apiUserAccount, item: nil as String?)
            try setKeychainItem(key: KeychainKey.bdbClientToken, item: nil as String?)
            try setKeychainItem(key: KeychainKey.bdbAuthUser, item: nil as String?)
            try setKeychainItem(key: KeychainKey.bdbAuthToken, item: nil as String?)
            try setKeychainItem(key: KeychainKey.creationTime, item: nil as Data?)
            try setKeychainItem(key: KeychainKey.pinFailTime, item: nil as Int64?)
            try setKeychainItem(key: KeychainKey.pinFailCount, item: nil as Int64?)
            try setKeychainItem(key: KeychainKey.pin, item: nil as String?)
            try setKeychainItem(key: KeychainKey.masterPubKey, item: nil as Data?)
            try setKeychainItem(key: KeychainKey.ethPrivKey, item: nil as String?)
            try setKeychainItem(key: KeychainKey.seed, item: nil as Data?)
            try setKeychainItem(key: KeychainKey.mnemonic, item: nil as String?, authenticated: true)
            print("[KEYSTORE] wiped")
            return true
        } catch let error {
            print("[KEYSTORE] wipe wallet error: \(error)")
            assertionFailure("keychain error: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: BIP39 Support

    func isSeedPhraseValid(_ phrase: String) -> Bool {
        assert(!allBip39WordLists.isEmpty)
        for wordList in allBip39WordLists {
            guard let nfkdPhrase = CFStringCreateMutableCopy(secureAllocator, 0, phrase as CFString) else { return false }
            CFStringNormalize(nfkdPhrase, .KD)
            if Account.validatePhrase(nfkdPhrase as String, words: wordList.map { $0 as String }) {
                return true
            }
        }
        return false
    }

    func isSeedWordValid(_ word: String) -> Bool {
        assert(!allBip39Words.isEmpty)
        return allBip39Words.contains(word)
    }
}

// MARK: - Testing Support

extension KeyStore {
    func destroy() {
        guard E.isRunningTests else { return assertionFailure("this method is only to be used by unit tests") }
        KeyStore.instance = nil
    }
}

// MARK: -

struct NoAuthWalletAuthenticator: WalletAuthenticator {
    
    var apiUserAccount: [AnyHashable: Any]?
    
    var noWallet: Bool { return true }
    var creationTime: Date { return Date(timeIntervalSinceReferenceDate: C.bip39CreationTime) }
    var apiAuthKey: Key? { return nil }
    var userAccount: [AnyHashable: Any]?

    var isBiometricsEnabledForUnlocking: Bool = false
    var isBiometricsEnabledForTransactions: Bool = false
    
    var pinLoginRequired: Bool { return false }
    var pinLength: Int { assertionFailure(); return 0 }
    var pinAttemptsRemaining: Int { return 0 }
    
    var walletDisabledUntil: TimeInterval { return TimeInterval() }

    func authenticate(withPin: String) -> Bool {
        assertionFailure()
        return false
    }

    func authenticate(withPhrase: String) -> Bool {
        assertionFailure()
        return false
    }

    func authenticate(withBiometricsPrompt: String, completion: @escaping (BiometricsResult) -> Void) {
        assertionFailure()
        completion(.failure)
    }

    func authenticateWithBlockchainDB(client: AuthenticationClient, completion: @escaping (APIAuthenticationResult) -> Void) {
        assertionFailure()
        completion(.failure(.invalidKey))
    }
    
    func loadAccount() -> Result<Account, AccountError> {
        assertionFailure()
        return .failure(.noAccount)
    }

    func createAccount(withPin: String) -> Account? {
        assertionFailure()
        return nil
    }

    func createAccount(withBiometricsPrompt: String, completion: @escaping (Account?) -> Void) {
        assertionFailure()
        completion(nil)
    }

    func buildBitIdKey(url: String, index: Int) -> Key? {
        assertionFailure()
        return nil
    }
}

// MARK: - Keychain Support

private struct KeychainKey {
    public static let biometricsUnlocking = "biometricsUnlocking"
    public static let biometricsTransactions = "biometricsTransactions"
    public static let mnemonic = "mnemonic"
    public static let creationTime = "creationtime"
    public static let pin = "pin"
    public static let pinFailCount = "pinfailcount"
    public static let pinFailTime = "pinfailheight"
    public static let apiAuthKey = "authprivkey"
    public static let apiUserAccount = "https://api.breadwallet.com"
    public static let bdbClientToken = "bdbClientToken"
    public static let bdbAuthUser = "bdbAuthUser"
    public static let bdbAuthToken = "bdbAuthToken"
    public static let systemAccount = "systemAccount"
    public static let seed = "seed" // deprecated
    public static let masterPubKey = "masterpubkey" // deprecated
    public static let ethPrivKey = "ethprivkey" // deprecated
}

private func keychainItem<T>(key: String) throws -> T? {
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

private func setKeychainItem<T>(key: String, item: T?, authenticated: Bool = false) throws {
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
