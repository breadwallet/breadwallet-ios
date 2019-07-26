//
//  WalletLockingTests.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-02-17.
//  Copyright © 2017-2019 Breadwinner AG. All rights reserved.
//

import XCTest
import LocalAuthentication
@testable import breadwallet

class WalletAuthenticationTests : XCTestCase {

    /// A class faking Touch/Face ID availability and successful user verification
    class StubLAContextAvailableSuccess: LAContext {
        override func evaluatePolicy(_ policy: LAPolicy, localizedReason: String, reply: @escaping (Bool, Error?) -> Void) {
            reply(true, nil)
        }

        override func canEvaluatePolicy(_ policy: LAPolicy, error: NSErrorPointer) -> Bool { return true }
    }

    /// A class faking Touch/Face ID availability and failed user verification
    class StubLAContextAvailableFailure: LAContext {
        override func evaluatePolicy(_ policy: LAPolicy, localizedReason: String, reply: @escaping (Bool, Error?) -> Void) {
            reply(false, nil)
        }

        override func canEvaluatePolicy(_ policy: LAPolicy, error: NSErrorPointer) -> Bool { return true }
    }

    /// A class faking Touch/Face ID availability and failed user verification
    class StubLAContextUnavailable: LAContext {
        override func evaluatePolicy(_ policy: LAPolicy, localizedReason: String, reply: @escaping (Bool, Error?) -> Void) {
            reply(false, nil)
        }

        override func canEvaluatePolicy(_ policy: LAPolicy, error: NSErrorPointer) -> Bool { return false }
    }


    private var keyStore: KeyStore!
    private let pin = "123456"
    private var seedPhrase: String!

    override func setUp() {
        super.setUp()
        clearKeychain()
        keyStore = try! KeyStore.create()
        XCTAssert(keyStore.setPin(pin), "Setting PIN should succeed")
        if let (phrase, _) = keyStore.setRandomSeedPhrase() {
            seedPhrase = phrase
        }
        XCTAssertNotNil(seedPhrase)
    }

    override func tearDown() {
        super.tearDown()
        clearKeychain()
        keyStore.destroy()
    }

    func testPinAuthentication() {
        XCTAssert(keyStore.authenticate(withPin: pin), "Authentication with correct PIN should succeed")
        XCTAssertFalse(keyStore.authenticate(withPin: "654321"), "Authentication with incorrect PIN should fail")
        XCTAssert(keyStore.pinLength == pin.count)
    }

    func testPhraseAuthentication() {
        XCTAssert(keyStore.authenticate(withPhrase: seedPhrase), "Authentication with correct phrase should succeed")
        XCTAssertFalse(keyStore.authenticate(withPhrase: "marine sand egg submit hotel flower taxi accident square lunch certain inmate"), "Authentication with incorrect phrase should fail")
    }

    func testBiometricAuthentication() {
        let expectation = XCTestExpectation(description: "Biometric authentication")
        expectation.expectedFulfillmentCount = 3

        keyStore.authenticate(withBiometricsPrompt: "Test", context: StubLAContextAvailableSuccess(), completion: { result in
            XCTAssert(result == .success)
            expectation.fulfill()
        })

        keyStore.authenticate(withBiometricsPrompt: "Test", context: StubLAContextAvailableFailure(), completion: { result in
            XCTAssert(result == .failure)
            expectation.fulfill()
        })

        keyStore.authenticate(withBiometricsPrompt: "Test", context: StubLAContextUnavailable(), completion: { result in
            XCTAssert(result == .failure)
            expectation.fulfill()
        })

        wait(for: [expectation], timeout: 10)
    }
    
    func testAccountSerialization() {
        // load the account created during setup
        guard case .success(let loadedAccount) = keyStore.loadAccount() else { return XCTFail("Loading account from serialization should succesed") }
        guard let createdAccount = keyStore.createAccount(withPin: pin) else { return XCTFail("Creating account should succesed") }
        let serializedAccount = createdAccount.serialize
        XCTAssert(loadedAccount.validate(serialization: serializedAccount))
        // load the newly created account
        guard case .success = keyStore.loadAccount() else { return XCTFail("Loading account from serialization should succesed") }
    }
    
    func testMigrationToAccount() {
        let mpkKey = "masterpubkey"
        let accountKey = "systemAccount"
        // simulate upgrade from pre-Account app version
        
        // remove account from keychain
        let accountQuery = [kSecClass as String: kSecClassGenericPassword as String,
                            kSecAttrService as String: testWalletSecAttrService,
                            kSecAttrAccount as String: accountKey]
        XCTAssert(SecItemDelete(accountQuery as CFDictionary) == noErr)
        XCTAssert(SecItemCopyMatching(accountQuery as CFDictionary, nil) == errSecItemNotFound)
        
        // add a dummy masterPubKey to keychain
        let mpkQuery = [kSecClass as String: kSecClassGenericPassword as String,
                        kSecAttrService as String: testWalletSecAttrService,
                        kSecAttrAccount as String: mpkKey]
        let data = "xpub6B3h7UmH1oMugVBytPLVaJdQjyuVFvSj9j3iZzT21DyNu39UvtWf8juT7w5tHDHo3yf7Pe2QNKfDt2gyNSNdVCfSK4Co61NKKcz31t8xK4s".data(using: .utf8)
        let item = [kSecClass as String: kSecClassGenericPassword as String,
                    kSecAttrService as String: testWalletSecAttrService,
                    kSecAttrAccount as String: mpkKey,
                    kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                    kSecValueData as String: data as Any]
        XCTAssert(SecItemAdd(item as CFDictionary, nil) == noErr)
        XCTAssert(SecItemCopyMatching(mpkQuery as CFDictionary, nil) != errSecItemNotFound)
        
        // test migration case detected
        guard case .failure(let error) = keyStore.loadAccount() else { return XCTFail() }
        XCTAssert(error == .invalidSerialization)
        
        // migrate by creating account
        let account = keyStore.createAccount(withPin: pin)
        XCTAssertNotNil(account)
        guard case .success = keyStore.loadAccount() else { return XCTFail() }
        
        // test old keys removed
        XCTAssert(SecItemCopyMatching(mpkQuery as CFDictionary, nil) == errSecItemNotFound)
    }

    func testWalletDisabled() {
        // Initial state
        XCTAssert(keyStore.walletDisabledUntil == 0)
        XCTAssertFalse(keyStore.walletIsDisabled)
        XCTAssert(keyStore.pinAttemptsRemaining == 8)

        // Perform 2 wrong pin attempts
        XCTAssertFalse(keyStore.authenticate(withPin: "654321"), "Authentication with wrong PIN should fail.")
        XCTAssertFalse(keyStore.authenticate(withPin: "839405"), "Authentication with wrong PIN should fail.")
        XCTAssert(keyStore.walletDisabledUntil == 0, "Wallet should not be disabled after 2 wrong pin attempts")
        XCTAssertFalse(keyStore.walletIsDisabled)
        XCTAssert(keyStore.pinAttemptsRemaining == 6)

        // Perform another wrong attempt that should disable the wallet
        XCTAssertFalse(keyStore.authenticate(withPin: "127345"), "Authentication with wrong PIN should fail.")
        let disabledUntil = keyStore.walletDisabledUntil
        XCTAssert(disabledUntil > Date().timeIntervalSince1970, "Wallet should be disabled until some time in the future. DisabledUntil: \(disabledUntil)")
        XCTAssert(keyStore.walletIsDisabled)
        XCTAssert(keyStore.pinAttemptsRemaining == 5)

        // Auth with correct pin should fail since wallet is disabled
        XCTAssertFalse(keyStore.authenticate(withPin: pin), "Authentication with correct PIN should fail when wallet disabled.")
        let disabledUntil2 = keyStore.walletDisabledUntil
        XCTAssert(disabledUntil2 == disabledUntil, "Wallet disabled timeout should not increase with correct attempt. DisabledUntil: \(disabledUntil2)")
        XCTAssert(keyStore.walletIsDisabled)
        XCTAssert(keyStore.pinAttemptsRemaining == 5)

        // Failed attempt when disabled does not count against fail count or disable time
        XCTAssertFalse(keyStore.authenticate(withPin: "987634"), "Authentication with wrong PIN should fail.")
        let disabledUntil3 = keyStore.walletDisabledUntil
        XCTAssert(disabledUntil3 == disabledUntil, "Wallet disabled timeout should increase with another failed attempt. DisabledUntil: \(disabledUntil3)")
        XCTAssert(keyStore.walletIsDisabled)
        XCTAssert(keyStore.pinAttemptsRemaining == 5)
    }

    func testChangePin() {
        let newPin = "54321"

        // Set initial pin
        XCTAssertFalse(keyStore.setPin(newPin), "Set pin should fail when pin already set.")

        // Change pin
        XCTAssert(keyStore.changePin(newPin: newPin, currentPin: pin), "Changing PIN with correct pin should succeed")
        XCTAssertFalse(keyStore.changePin(newPin: newPin, currentPin: pin), "Changing PIN with incorrect pin should fail")
        XCTAssert(keyStore.changePin(newPin: pin, currentPin: newPin), "Changing PIN with correct pin should succeed")
    }

    func testResetPin() {
        let newPin = "54321"
        let originalPin = pin

        // Attempt reset with wrong seed
        XCTAssertFalse(keyStore.resetPin(newPin: newPin, seedPhrase: "marine sand egg submit hotel flower taxi accident square lunch certain inmate"), "Resetting PIN with incorrect seed should fail")
        XCTAssertFalse(keyStore.authenticate(withPin: newPin), "Authentication with new pin should fail.")
        XCTAssert(keyStore.authenticate(withPin: originalPin), "Authentication with current pin should succeed.")

        // Reset with correct seed - PIN is newPin
        XCTAssert(keyStore.resetPin(newPin: newPin, seedPhrase: seedPhrase), "PIN reset with correct seed phrase should succeed.")
        XCTAssert(keyStore.authenticate(withPin: newPin), "Authentication with new pin should succeed")
        XCTAssertFalse(keyStore.authenticate(withPin: originalPin), "Authentication with old pin should fail")

        // Disable wallet
        XCTAssertFalse(keyStore.authenticate(withPin: "654322"), "Authentication with wrong PIN should fail.")
        XCTAssertFalse(keyStore.authenticate(withPin: "839408"), "Authentication with wrong PIN should fail.")
        XCTAssertFalse(keyStore.authenticate(withPin: "127346"), "Authentication with wrong PIN should fail.")
        XCTAssert(keyStore.walletIsDisabled, "Wallet should be disabled after 3 failed PIN attempts")
        XCTAssertFalse(keyStore.authenticate(withPin: newPin), "Authentication with correct PIN should fail when wallet disabled.")

        // Attempt reset with wrong seed
        XCTAssertFalse(keyStore.resetPin(newPin: originalPin, seedPhrase: "marine sand egg submit hotel flower taxi accident square lunch certain inmate"), "Resetting PIN with incorrect seed should fail")
        XCTAssert(keyStore.walletIsDisabled, "Wallet should be disabled after failed reset attempt")
        XCTAssertFalse(keyStore.authenticate(withPin: newPin), "Authentication with correct PIN should fail when wallet disabled.")
        XCTAssertFalse(keyStore.authenticate(withPin: originalPin), "Authentication with incorrect PIN should fail.")

        // Reset with correct seed to originalPin
        XCTAssert(keyStore.resetPin(newPin: originalPin, seedPhrase: seedPhrase), "Resetting PIN should succeed")
        XCTAssert(keyStore.walletDisabledUntil == 0, "Wallet should not be disabled after PIN reset")
        XCTAssertFalse(keyStore.authenticate(withPin: newPin), "Authentication with previous pin should fail.")
        XCTAssert(keyStore.authenticate(withPin: originalPin), "Authentication with correct pin should succeed.")
    }
}
