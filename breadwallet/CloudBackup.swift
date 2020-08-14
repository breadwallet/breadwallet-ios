// 
//  CloudBackup.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2020-07-28.
//  Copyright © 2020 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import Foundation
import CryptoKit
import CommonCrypto
import UIKit

@available(iOS 13.6, *)
struct CloudBackup: Codable {
    let identifier: String
    let createTime: Date
    let deviceName: String
    let salt: Data
    
    static let noIDKey = "no-wallet-id-key"
    
    fileprivate let encryptedData: Data
    
    init(phrase: String, identifier: String, pin: String) {
        self.identifier = identifier
        self.createTime = Date()
        self.deviceName = UIDevice.current.name
        let salt = CloudBackupCrypto.randomData(length: 64)
        self.salt = salt
        let sealed = CloudBackupCrypto.encrypt(input: phrase, withPin: pin, salt: salt)
        self.encryptedData = sealed?.combined ?? Data()
    }
    
    private init(encryptedData: Data, identifier: String, createTime: Date, deviceName: String, salt: Data) {
        self.encryptedData = encryptedData
        self.identifier = identifier
        self.createTime = createTime
        self.deviceName = deviceName
        self.salt = salt
    }
    
    func recoverPhrase(withPin pin: String, salt: Data) -> String {
        return CloudBackupCrypto.extractKey(input: encryptedData, withPin: pin, salt: salt)
    }
    
    func migrateId(toId newId: String) -> CloudBackup {
        return CloudBackup(encryptedData: encryptedData,
                           identifier: newId,
                           createTime: createTime,
                           deviceName: deviceName,
                           salt: salt)
    }
}

@available(iOS 13.6, *)
enum CloudBackupCrypto {
    
    static func encrypt(input: String, withPin pin: String, salt: Data) -> ChaChaPoly.SealedBox? {
        let keyData = CloudBackupCrypto.keyData(forPin: pin, salt: salt)
        let key = SymmetricKey(data: keyData)
        do {
            return try ChaChaPoly.seal(input.data(using: .utf8)!, using: key)
        } catch let e {
            print("[CloudBackup] encrypt error: \(e)")
        }
        return nil
    }
    
    static func extractKey(input: Data, withPin pin: String, salt: Data) -> String {
        let keyData = CloudBackupCrypto.keyData(forPin: pin, salt: salt)
        let key = SymmetricKey(data: keyData)
        do {
            let sealed = try ChaChaPoly.SealedBox(combined: input)
            let decryptedData = try ChaChaPoly.open(sealed, using: key)
            return String(data: decryptedData, encoding: .utf8) ?? ""
        } catch let e {
            print("[CloudBackup] encryption error: \(e)")
        }
        return ""
    }
    
    static func keyData(forPin pin: String, salt: Data) -> Data {
        guard let keyData = CloudBackupCrypto.pbkdf2(hash: CCPBKDFAlgorithm(kCCPRFHmacAlgSHA512),
                             password: pin,
                             saltData: salt,
                             keyByteCount: 32, //256-bit
                             rounds: 100000) else { fatalError() }
        return keyData
    }
    
    static func pbkdf2(hash: CCPBKDFAlgorithm, password: String, saltData: Data, keyByteCount: Int, rounds: Int) -> Data? {
        guard let passwordData = password.data(using: .utf8) else { return nil }
        var derivedKeyData = Data(repeating: 0, count: keyByteCount)
        let derivedCount = derivedKeyData.count
        let derivationStatus: Int32 = derivedKeyData.withUnsafeMutableBytes { derivedKeyBytes in
            let keyBuffer: UnsafeMutablePointer<UInt8> =
                derivedKeyBytes.baseAddress!.assumingMemoryBound(to: UInt8.self)
            return saltData.withUnsafeBytes { saltBytes -> Int32 in
                let saltBuffer: UnsafePointer<UInt8> = saltBytes.baseAddress!.assumingMemoryBound(to: UInt8.self)
                return CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    password,
                    passwordData.count,
                    saltBuffer,
                    saltData.count,
                    hash,
                    UInt32(rounds),
                    keyBuffer,
                    derivedCount)
            }
        }
        return derivationStatus == kCCSuccess ? derivedKeyData : nil
    }
    
    static func randomData(length: Int) -> Data {
        var data = Data(count: length)
        _ = data.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, length, $0.baseAddress!)
        }
        return data
    }
}
