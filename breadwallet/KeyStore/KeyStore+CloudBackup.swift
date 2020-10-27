// 
//  KeyStore+CloudBackup.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2020-08-12.
//  Copyright © 2020 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import Foundation
import WalletKit

@available(iOS 13.6, *)
extension KeyStore: Trackable {
    
    func doesCurrentWalletHaveBackup() -> Bool {
        let id = Store.state.walletID ?? CloudBackup.noIDKey
        let backup = listBackups().first(where: { $0.identifier == id })
        return backup != nil
    }
    
    func unlockBackup(pin: String, key: String) -> Result<Account, Error> {
        guard unlockBackupPinAttemptsRemaining > 0 else { return .failure(UnlockBackupError.backupDeleted) }
        let backups = listBackups()
        guard let backup = backups.first(where: { $0.identifier == key }) else { return .failure(UnlockBackupError.noBackupFound) }
        let phrase = backup.recoverPhrase(withPin: pin, salt: backup.salt)
        guard !phrase.isEmpty else {
            if unlockBackupPinAttemptsRemaining == 1 {
                deleteBackupFor(key: key)
                return .failure(UnlockBackupError.backupDeleted)
            } else {
                let attemptsRemaining = incrementFailedBackupCount(pin: pin)
                return .failure(UnlockBackupError.wrongPin(attemptsRemaining))
            }
        }
        resetFailedBackupCount()
        guard let account = setSeedPhrase(phrase) else { return .failure(UnlockBackupError.couldNotCreateAccount)}
        guard setPin(pin) else { fatalError() }
        return .success(account)
    }
    
    // Increments pin failed count and returns
    // attempts remaining
    private func incrementFailedBackupCount(pin: String) -> Int {
        var failCount: Int64 = (try? keychainItem(key: KeychainKey.cloudPinFailCount)) ?? 0
        if !KeyStore.failedBackupPins.contains(pin) {
            KeyStore.failedBackupPins.append(pin)
            failCount += 1
            try? setKeychainItem(key: KeychainKey.cloudPinFailCount, item: Int64(failCount))
        }
        return unlockBackupPinAttemptsRemaining
    }
    
    private func resetFailedBackupCount() {
        try? setKeychainItem(key: KeychainKey.cloudPinFailCount, item: Int64(0))
        KeyStore.failedBackupPins.removeAll()
    }
    
    private func deleteBackupFor(key: String) {
        guard let backup = listBackups().first(where: { $0.identifier == key }) else { return }
        _ = deleteBackup(backup)
        resetFailedBackupCount()
    }
    
    /// number of unique failed pin attempts remaining before wallet is wiped
    private var unlockBackupPinAttemptsRemaining: Int {
        do {
            let failCount: Int64 = try keychainItem(key: KeychainKey.cloudPinFailCount) ?? 0
            return Int(maxBackupPinAttemptsBeforeWipe - failCount)
        } catch { return -1 }
    }
    
    func listBackups() -> [CloudBackup] {
        let data = getAllKeyChainItemsOfClass(kSecClassGenericPassword as String)
        var results = [CloudBackup]()
        data.forEach { (key, val) in
            do {
                let backup = try JSONDecoder().decode(CloudBackup.self, from: val)
                results.append(backup)
            } catch _ {
                print("[CloudBackups] found unknown: \(key)")
            }
        }
        return results
    }

    func deleteBackup(_ backupData: CloudBackup) -> Bool {
        let query = [kSecClass as String: kSecClassGenericPassword as String,
                    kSecAttrService as String: WalletSecAttrService,
                    kSecAttrAccount as String: backupData.identifier,
                    kSecAttrSynchronizable as String: true as CFBoolean
            ] as [String: Any]
        var status = noErr
        if SecItemCopyMatching(query as CFDictionary, nil) != errSecItemNotFound {
            status = SecItemDelete(query as CFDictionary)
            saveEvent("backup.delete")
        }
        guard status == noErr else { return false }
        return true
    }
     
    //Used for backing up existing wallet
    //Since this happens after onboarding, we will have a walletId
    func addBackup(forPin pin: String) -> Bool {
         guard let phrase = seedPhrase(pin: pin) else { return false }
         guard let id = Store.state.walletID else { return false }
         let backup = CloudBackup(phrase: phrase, identifier: id, pin: pin)
         return addBackup(backup)
    }

    func addBackup() -> Bool {
        guard let pin: String = try? keychainItem(key: KeychainKey.pin) else { return false }
        guard let phrase = seedPhrase(pin: pin) else { return false }
        let id = CloudBackup.noIDKey
        let backup = CloudBackup(phrase: phrase, identifier: id, pin: pin)
        return addBackup(backup)
    }
     
    func migrateNoKeyBackup(id: String) {
        guard let oldBackup = listBackups().first(where: { $0.identifier == CloudBackup.noIDKey }) else { return }
        let newBackup = oldBackup.migrateId(toId: id)
        _ = deleteBackup(oldBackup)
        _ = addBackup(newBackup)
    }
    
    func updateBackupPin(newPin: String, currentPin: String, forKey: String) -> Bool {
        guard let backup = listBackups().first(where: { $0.identifier == forKey }) else { return false }
        let phrase = backup.recoverPhrase(withPin: currentPin, salt: backup.salt)
        guard !phrase.isEmpty else { return false }
        let newBackup = CloudBackup(phrase: phrase, identifier: backup.identifier, pin: newPin)
        return addBackup(newBackup)
    }
     
    func deleteAllBackups() {
        listBackups().forEach {
            _ = self.deleteBackup($0)
        }
    }
     
    func deleteCurrentBackup() {
        let ids = [Store.state.walletID, CloudBackup.noIDKey].compactMap { $0 }
        ids.forEach { id in
            print("[CloudBackups] deleting key: \(id)")
            let backups = listBackups().filter({ $0.identifier == id })
            backups.forEach {
                _ = self.deleteBackup($0)
            }
        }
    }
     
    func addBackup(_ backupData: CloudBackup) -> Bool {
        let query = [kSecClass as String: kSecClassGenericPassword as String,
                    kSecAttrService as String: WalletSecAttrService,
                    kSecAttrAccount as String: backupData.identifier,
                    kSecAttrSynchronizable as String: true as CFBoolean
            ] as [String: Any]
        var status = noErr
        var data: Data
        do {
            data = try JSONEncoder().encode(backupData)
        } catch _ {
            return false
        }
         
        if SecItemCopyMatching(query as CFDictionary, nil) != errSecItemNotFound { // update existing item
            let update = [kSecValueData as String: data as Any]
            status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        } else { // add new item
            let item = [kSecClass as String: kSecClassGenericPassword as String,
                        kSecAttrService as String: WalletSecAttrService,
                        kSecAttrAccount as String: backupData.identifier,
                        kSecValueData as String: data as Any,
                        kSecAttrSynchronizable as String: true as CFBoolean
            ]
            status = SecItemAdd(item as CFDictionary, nil)
            saveEvent("backup.add")
        }

        guard status == noErr else {
            return false }
         
        return true
    }
    
    private func getAllKeyChainItemsOfClass(_ secClass: String) -> [String: Data] {

        let query: [String: Any] = [
            kSecClass as String: secClass,
            kSecReturnData as String: true as CFBoolean,
            kSecReturnAttributes as String: true as CFBoolean,
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecAttrService as String: WalletSecAttrService,
            kSecAttrSynchronizable as String: true as CFBoolean
        ]

        var result: AnyObject?
        let lastResultCode = withUnsafeMutablePointer(to: &result) {
            SecItemCopyMatching(query as CFDictionary, UnsafeMutablePointer($0))
        }

        var values = [String: Data]()
        if lastResultCode == noErr {
            if let array = result as? [[String: Any]] {
                for item in array {
                    if let key = item[kSecAttrAccount as String] as? String,
                        let value = item[kSecValueData as String] as? Data {
                        values[key] = value
                    }
                }
            }
        }

        return values
    }
}
