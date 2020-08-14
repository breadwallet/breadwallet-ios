// 
//  CloudBackupTests.swift
//  breadwalletTests
//
//  Created by Adrian Corscadden on 2020-07-27.
//  Copyright © 2020 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import XCTest
@testable import breadwallet

private var keyStore: KeyStore!

private let pin = "123456"
private let phrase = "this is a test phrase"
private let phrase2 = "this is a second test phrase"

@available(iOS 13.6, *)
class CloudBackupTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        clearKeychain()
        keyStore = try! KeyStore.create()
    }
    
    override func tearDown() {
        super.tearDown()
        clearKeychain()
        keyStore.destroy()
    }
    
    func testStoreBackup() {
        XCTAssertTrue(keyStore.listBackups().count == 0, "Backups count should be initially 0")
        let backup = CloudBackup(phrase: phrase, identifier: "backup-key", pin: pin)
        XCTAssertTrue(keyStore.addBackup(backup))
        let recoveredBackups = keyStore.listBackups()
        XCTAssertTrue(recoveredBackups.count == 1, "Backups count should be 1 after 1 added")
        if let recoveredBackup = recoveredBackups.first {
            XCTAssertTrue(recoveredBackup.identifier == "backup-key", "Backed up key should match")
            XCTAssertTrue(recoveredBackup.recoverPhrase(withPin: pin, salt: recoveredBackup.salt) == phrase, "Backed up val should match")
        } else {
            XCTFail("A recovered backup should exist")
        }
    }
    
    func testWrongPin() {
        XCTAssertTrue(keyStore.listBackups().count == 0, "Backups count should be initially 0")
        let backup = CloudBackup(phrase: phrase, identifier: "backup-key", pin: pin)
        XCTAssertTrue(keyStore.addBackup(backup))
        let recoveredBackups = keyStore.listBackups()
        XCTAssertTrue(recoveredBackups.count == 1, "Backups count should be 1 after 1 added")
        if let recoveredBackup = recoveredBackups.first {
            XCTAssertTrue(recoveredBackup.identifier == "backup-key", "Backed up key should match")
            XCTAssertTrue(recoveredBackup.recoverPhrase(withPin: "111111", salt: recoveredBackup.salt) != phrase, "Backed up val should match")
        } else {
            XCTFail("A recovered backup should exist")
        }
    }
    
    func testUpdateBackup() {
        let backup = CloudBackup(phrase: phrase, identifier: "backup-key", pin: pin)
        XCTAssertTrue(keyStore.addBackup(backup))
        let backup2 = CloudBackup(phrase: phrase2, identifier: "backup-key", pin: pin)
        XCTAssertTrue(keyStore.addBackup(backup2))

        let recoveredBackups = keyStore.listBackups()
        XCTAssertTrue(recoveredBackups.count == 1, "Backups count should be 1 after 1 added and updated")
        if let recoveredBackup = recoveredBackups.first {
           XCTAssertTrue(recoveredBackup.identifier == "backup-key", "Backed up key should match")
           XCTAssertTrue(recoveredBackup.recoverPhrase(withPin: pin, salt: recoveredBackup.salt) == phrase2, "Backed up val should match")
        } else {
            XCTFail("A recovered backup should exist")
        }
    }

    func testDeleteBackup() {
        let backup = CloudBackup(phrase: phrase, identifier: "backup-key", pin: pin)
        _ = keyStore.addBackup(backup)
        XCTAssertTrue(keyStore.listBackups().count == 1, "Backups count should be 1 after 1 added")
        XCTAssertTrue(keyStore.deleteBackup(backup), "Deletion should return true")
        XCTAssertTrue(keyStore.listBackups().count == 0, "Backups count should be 0 after deletion")
    }
    
    func testUpdatePin() {
        let backup = CloudBackup(phrase: phrase, identifier: "backup-key", pin: pin)
        _ = keyStore.addBackup(backup)
        XCTAssertTrue(keyStore.listBackups().count == 1, "Backups count should be 1 after 1 added")
        let result = keyStore.updateBackupPin(newPin: "111111", currentPin: pin, forKey: "backup-key")
        XCTAssert(result, "updateBackupPin call should succeed")
        guard let updatedBackup = keyStore.listBackups().first else { XCTFail(); return }
        let recoveredPhrase = updatedBackup.recoverPhrase(withPin: "111111", salt: updatedBackup.salt)
        print("phrase: \(recoveredPhrase)")
        XCTAssert(phrase == recoveredPhrase, "Recovered phrase should match")
    }
    
}
