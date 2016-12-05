//
//  WalletManager+Auth.swift
//  breadwallet
//
//  Created by Aaron Voisine on 11/7/16.
//  Copyright (c) 2016 breadwallet LLC
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

import Foundation
import UIKit
import LocalAuthentication
import BRCore
import CSQLite3

private func secureAllocate(allocSize: CFIndex, hint: CFOptionFlags, info: UnsafeMutableRawPointer?)
    -> UnsafeMutableRawPointer?
{
    guard let ptr = malloc(MemoryLayout<CFIndex>.stride + allocSize) else { return nil }

    // keep track of the size of the allocation so it can be cleansed before deallocation
    ptr.assumingMemoryBound(to: CFIndex.self).pointee = MemoryLayout<CFIndex>.stride + allocSize
    return ptr + MemoryLayout<CFIndex>.stride
}

private func secureDeallocate(ptr: UnsafeMutableRawPointer?, info: UnsafeMutableRawPointer?)
{
    guard let ptr = ptr?.advanced(by: -MemoryLayout<CFIndex>.stride) else { return }
    
    memset(ptr, 0, ptr.assumingMemoryBound(to: CFIndex.self).pointee) // cleanse allocated memory
    free(ptr)
}

private func secureReallocate(ptr: UnsafeMutableRawPointer?, newsize: CFIndex, hint: CFOptionFlags,
                              info: UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer?
{
    // there's no way to tell ahead of time if the original memory will be deallocted even if the new size is smaller
    // than the old size, so just cleanse and deallocate every time
    guard let ptr = ptr else { return nil }
    let newptr = secureAllocate(allocSize: newsize, hint: hint, info: info)
    let size = (ptr - MemoryLayout<CFIndex>.stride).assumingMemoryBound(to: CFIndex.self).pointee
    
    if (newptr != nil) {
        memcpy(newptr, ptr, (size < newsize) ? size : newsize)
    }
    
    secureDeallocate(ptr: ptr, info: info)
    return newptr
}

// since iOS does not page memory to disk, all we need to do is cleanse allocated memory prior to deallocation
public let secureAllocator: CFAllocator = {
    var context = CFAllocatorContext()

    context.version = 0;
    CFAllocatorGetContext(kCFAllocatorDefault, &context)
    context.allocate = secureAllocate
    context.reallocate = secureReallocate;
    context.deallocate = secureDeallocate;
    return CFAllocatorCreate(kCFAllocatorDefault, &context).takeRetainedValue()
}()

private let WalletSecAttrService = "org.voisine.breadwallet"
private let SeedEntropyLength = (128/8)

private func keychainItem<T>(key: String) throws -> T? {
    let query = [kSecClass as String : kSecClassGenericPassword as String,
                 kSecAttrService as String : WalletSecAttrService,
                 kSecAttrAccount as String : key,
                 kSecReturnData as String : true as Any]
    var result: CFTypeRef? = nil
    let status = SecItemCopyMatching(query as CFDictionary, &result);
    
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
        return data.withUnsafeBytes({ $0.pointee })
    case is Dictionary<AnyHashable, Any>.Type:
        return NSKeyedUnarchiver.unarchiveObject(with: data) as? T
    default:
        throw NSError(domain: NSOSStatusErrorDomain, code: Int(errSecParam))
    }
}

private func setKeychainItem<T>(key: String, item: T?, authenticated: Bool = false) throws {
    let accessible = (authenticated) ? kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String
                                     : kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String
    let query = [kSecClass as String : kSecClassGenericPassword as String,
                 kSecAttrService as String : WalletSecAttrService,
                 kSecAttrAccount as String : key]
    var status = noErr
    var data: Data? = nil
    if let item = item {
        switch T.self {
        case is Data.Type:
            data = item as? Data
        case is String.Type:
            data = CFStringCreateExternalRepresentation(secureAllocator, item as! CFString,
                                                        CFStringBuiltInEncodings.UTF8.rawValue, 0) as Data
        case is Int64.Type:
            data = CFDataCreateMutable(secureAllocator, MemoryLayout<T>.stride) as Data
            data?.append(UnsafeBufferPointer(start: [item], count: 1))
        case is Dictionary<AnyHashable, Any>.Type:
            data = NSKeyedArchiver.archivedData(withRootObject: item)
        default:
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(errSecParam))
        }
    }
    
    if data == nil { // delete item
        if SecItemCopyMatching(query as CFDictionary, nil) != errSecItemNotFound {
            status = SecItemDelete(query as CFDictionary)
        }
    }
    else if SecItemCopyMatching(query as CFDictionary, nil) != errSecItemNotFound { // update existing item
        let update = [kSecAttrAccessible as String : accessible,
                      kSecValueData as String : data as Any]
        
        status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
    }
    else { // add new item
        let item = [kSecClass as String : kSecClassGenericPassword as String,
                    kSecAttrService as String : WalletSecAttrService,
                    kSecAttrAccount as String : key,
                    kSecAttrAccessible as String : accessible,
                    kSecValueData as String : data as Any]
        
        status = SecItemAdd(item as CFDictionary, nil)
    }
    
    guard status == noErr else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
}

extension WalletManager {
    static private var failedPins = [String]()
    
    convenience init(dbPath: String? = nil) throws {
        if !UIApplication.shared.isProtectedDataAvailable {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(errSecNotAvailable))
        }
        
        if try keychainItem(key: keychainKey.seed) as Data? != nil { // upgrade from old keychain scheme
            let seedPhrase: String? = try keychainItem(key: keychainKey.mnemonic)
            var seed = UInt512()
            var mpk = BRMasterPubKey()
            
            print("upgrading to authenticated keychain scheme")
            BRBIP39DeriveKey(&seed.u8.0, seedPhrase, nil)
            mpk = BRBIP32MasterPubKey(&seed, MemoryLayout<UInt512>.size)
            seed = UInt512() // clear seed
            try setKeychainItem(key: keychainKey.mnemonic, item: seedPhrase, authenticated: true)
            try setKeychainItem(key: keychainKey.masterPubKey,
                                item: Data(buffer: UnsafeBufferPointer(start: [mpk], count: 1)))
            try setKeychainItem(key: keychainKey.seed, item: nil as Data?)
        }

        guard let mpk: Data = try keychainItem(key: keychainKey.masterPubKey),
              mpk.count >= MemoryLayout<BRMasterPubKey>.stride else {
            try self.init(masterPubKey: BRMasterPubKey(), earliestKeyTime: 0, dbPath: dbPath)
            return
        }
        
        var earliestKeyTime = Double(BIP39_CREATION_TIME) - NSTimeIntervalSince1970
        if let creationTime: Data = try keychainItem(key: keychainKey.creationTime),
            creationTime.count == MemoryLayout<TimeInterval>.stride {
                earliestKeyTime = creationTime.withUnsafeBytes({ $0.pointee })
        }
        
        try self.init(masterPubKey: mpk.withUnsafeBytes({ $0.pointee }), earliestKeyTime: earliestKeyTime,
                      dbPath: dbPath)
    }
    
    // true if keychain is available and we know that no wallet exists on it
    func noWallet() -> Bool {
        if didInitWallet { return false }

        do {
            if try keychainItem(key: keychainKey.masterPubKey) as Data? != nil { return false }
            if try keychainItem(key: keychainKey.seed) as Data? != nil { return false } // check for old keychain scheme
        }
        catch { return false }
        
        return true
    }
    
    func canUseTouchID() -> Bool {
        let context = LAContext()

        return context.canEvaluatePolicy(LAPolicy.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }
    
    func canUseTouchID(forTx: inout BRTransaction) -> Bool {
        guard canUseTouchID() else { return false }
        
        do {
            let spendLimit : Int64 = try keychainItem(key: keychainKey.spendLimit) ?? 0
            
            return BRWalletAmountSentByTx(wallet?.ptr, &forTx) + BRWalletTotalSent(wallet?.ptr) <= UInt64(spendLimit)
        }
        catch { return false }
    }

    func pinAttemptsRemaining() -> Int {
        do {
            let failCount : Int64 = try keychainItem(key: keychainKey.pinFailCount) ?? 0
        
            return Int(8 - failCount)
        }
        catch { return -1 }
    }
    
    func walletDisabledUntil() -> TimeInterval {
        do {
            let failCount : Int64 = try keychainItem(key: keychainKey.pinFailCount) ?? 0
            guard failCount >= 3 else { return 0 }
            let failTime : Int64 = try keychainItem(key: keychainKey.pinFailTime) ?? 0
            
            return Double(failTime) + pow(6, Double(failCount - 3))*60
        }
        catch { return 0 }
    }
    
    func authenticate(pin: String) -> Bool {
        do {
            let secureTime = Date.timeIntervalSinceReferenceDate // TODO: XXX use secure time from https request
            var failCount : Int64 = try keychainItem(key: keychainKey.pinFailCount) ?? 0

            if failCount >= 3 {
                let failTime : Int64 = try keychainItem(key: keychainKey.pinFailTime) ?? 0

                if secureTime < Double(failTime) + pow(6, Double(failCount - 3))*60 { // locked out
                    return false
                }
            }
            
            if !WalletManager.failedPins.contains(pin) { // count unique attempts before checking success
                failCount += 1
                try setKeychainItem(key: keychainKey.pinFailCount, item: failCount)
            }
            
            if try pin == keychainItem(key: keychainKey.pin) { // successful pin attempt
                let limit = Int64(UserDefaults.standard.double(forKey: defaultsKey.spendLimitAmount))
                
                WalletManager.failedPins.removeAll()
                UserDefaults.standard.set(Date.timeIntervalSinceReferenceDate, forKey: defaultsKey.pinUnlockTime)
                try setKeychainItem(key: keychainKey.pinFailTime, item: Int64(0))
                try setKeychainItem(key: keychainKey.pinFailCount, item: Int64(0))
                
                if limit > 0 {
                    try setKeychainItem(key: keychainKey.spendLimit,
                                        item: Int64(BRWalletTotalSent(wallet?.ptr)) + limit)
                }
                
                return true
            }
            else if !WalletManager.failedPins.contains(pin) { // unique failed attempt
                WalletManager.failedPins.append(pin)
                
                if (failCount >= 8) { // wipe wallet after 8 failed pin attempts and 24+ hours of lockout
                    if !wipeWallet() { return false }
                    return false
                }
                
                if try secureTime > keychainItem(key: keychainKey.pinFailTime) ?? 0 {
                    try setKeychainItem(key: keychainKey.pinFailTime, item: secureTime)
                }
            }
            
            return false
        }
        catch { return false }
    }
    
    func authenticate(touchIDPrompt: String, completion: @escaping (Bool) -> ()) {
        LAContext().evaluatePolicy(LAPolicy.deviceOwnerAuthenticationWithBiometrics, localizedReason: touchIDPrompt,
                                   reply: { success, _ in DispatchQueue.main.async { completion(success) } })
    }
    
    func signTransaction(tx: inout BRTransaction, pin: String) -> Bool {
        guard authenticate(pin: pin) else { return false }
        return signTx(tx: &tx)
    }
    
    func signTransaction(tx: inout BRTransaction, touchIDPrompt: String, completion: @escaping (Bool) -> ()) {
        do {
            let spendLimit : Int64 = try keychainItem(key: keychainKey.spendLimit) ?? 0
            guard BRWalletAmountSentByTx(wallet?.ptr, &tx) + BRWalletTotalSent(wallet?.ptr) <= UInt64(spendLimit) else {
                return completion(false)
            }
        }
        catch { return completion(false) }
        
        let txRef = UnsafeMutablePointer(&tx)
            
        authenticate(touchIDPrompt: touchIDPrompt) { success in
            guard success else { return completion(false) }
            
            completion(self.signTx(tx: &txRef.pointee))
        }
    }
    
    func seedPhrase(pin: String) -> String? {
        guard authenticate(pin: pin) else { return nil }
        
        do {
            return try keychainItem(key: keychainKey.mnemonic)
        }
        catch { return nil }
    }

    func setSeedPhrase(phrase: String) -> Bool {
        guard noWallet() else { return false }
        
        do {
            var mpk = BRMasterPubKey()
            var seed = UInt512()

            try setKeychainItem(key: keychainKey.mnemonic, item: phrase, authenticated: true)
            BRBIP39DeriveKey(&seed.u8.0, phrase, nil)
            mpk = BRBIP32MasterPubKey(&seed, MemoryLayout<UInt512>.size)
            seed = UInt512() // clear seed
            try setKeychainItem(key: keychainKey.masterPubKey,
                                item: Data(buffer: UnsafeBufferPointer(start: [mpk], count: 1)))
            return true
        }
        catch { return false }
    }
    
    func setRandomSeed() -> String? {
        guard noWallet() else { return nil }
        guard let path = Bundle.main.path(forResource: "BIP39Words", ofType: "plist") else { return nil }
        guard let wordList = NSArray(contentsOfFile: path) as? [String], wordList.count == 2048 else { return nil }
        var words: [UnsafePointer<CChar>?] = wordList.map({ $0.withCString({ $0 }) })
        let time = Date.timeIntervalSinceReferenceDate

        // we store the wallet creation time on the keychain because keychain data persists even when app is deleted
        do {
            try setKeychainItem(key: keychainKey.creationTime,
                                item: Data(buffer: UnsafeBufferPointer(start: [time], count: 1)))
        }
        catch { return nil }

        return autoreleasepool { // wrapping in an autorelease pool ensures sensitive memory is wiped and released immediately
            var entropy = CFDataCreateMutable(secureAllocator, SeedEntropyLength) as Data
            var phrase = CFStringCreateMutable(secureAllocator, 0) as String
            var phraseLen = 0
            
            entropy.count = SeedEntropyLength
            guard SecRandomCopyBytes(kSecRandomDefault, entropy.count, entropy.withUnsafeMutableBytes({ $0 })) == 0
                else { return nil }
            phraseLen = BRBIP39Encode(nil, 0, &words, entropy.withUnsafeBytes({ $0 }), entropy.count)
            phrase.append(String(repeating:"\0", count:phraseLen))
            BRBIP39Encode(UnsafeMutablePointer(mutating: phrase), phrase.lengthOfBytes(using: .utf8), &words,
                          entropy.withUnsafeBytes({ $0 }), entropy.count)
            guard setSeedPhrase(phrase: phrase) else { return nil }

            return phrase
        }
    }
    
    func setPin(newPin: String, pin: String) -> Bool {
        guard authenticate(pin: pin) else { return false }

        do {
            try setKeychainItem(key: keychainKey.pin, item: newPin, authenticated: true)
            return true
        }
        catch { return false }
    }
    
    func wipeWallet(pin: String = "forceWipe") -> Bool {
        guard pin == "forceWipe" || authenticate(pin: pin) else { return false }
                
        do {
            if didInitWallet {
                if peerManager != nil { BRPeerManagerDisconnect(peerManager?.ptr) }
                if peerManager != nil { BRPeerManagerFree(peerManager?.ptr) }
                peerManager = nil
                if wallet != nil { BRWalletFree(wallet?.ptr) }
                wallet = nil
            }

            if db != nil { sqlite3_close(db) }
            db = nil
            try FileManager.default.removeItem(atPath: dbPath)
            
            try setKeychainItem(key: keychainKey.authPrivKey, item: nil as Data?)
            try setKeychainItem(key: keychainKey.spendLimit, item: nil as Int64?)
            try setKeychainItem(key: keychainKey.creationTime, item: nil as Data?)
            try setKeychainItem(key: keychainKey.pinFailTime, item: nil as Int64?)
            try setKeychainItem(key: keychainKey.pinFailCount, item: nil as Int64?)
            try setKeychainItem(key: keychainKey.pin, item: nil as String?)
            try setKeychainItem(key: keychainKey.masterPubKey, item: nil as Data?)
            try setKeychainItem(key: keychainKey.seed, item: nil as Data?)
            try setKeychainItem(key: keychainKey.mnemonic, item: nil as String?)
        }
        catch { return false }
        
        return true
    }
    
    private struct keychainKey {
        public static let mnemonic = "mnemonic"
        public static let creationTime = "creationtime"
        public static let masterPubKey = "masterpubkey"
        public static let spendLimit = "spendlimit"
        public static let pin = "pin"
        public static let pinFailCount = "pinfailcount"
        public static let pinFailTime = "pinfailheight" // value is for historical reasons
        public static let authPrivKey = "authprivkey"
        public static let userAccount = "https://api.breadwallet.com"
        public static let seed = "seed" // deprecated
    }
    
    private struct defaultsKey {
        public static let spendLimitAmount = "SPEND_LIMIT_AMOUNT"
        public static let pinUnlockTime = "PIN_UNLOCK_TIME"
    }
    
    private func signTx(tx: inout BRTransaction) -> Bool {
        return autoreleasepool {
            var seed = UInt512()
            defer { seed = UInt512() }
            
            do {
                guard let phrase: String = try keychainItem(key: keychainKey.mnemonic) else { return false }
                BRBIP39DeriveKey(&seed.u8.0, phrase, nil)
            }
            catch { return false }
            
            return BRWalletSignTransaction(wallet?.ptr, &tx, &seed, MemoryLayout<UInt512>.size) != 0
        }
    }
}

