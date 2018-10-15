//
//  PigeonTests.swift
//  breadwalletTests
//
//  Created by Adrian Corscadden on 2018-07-16.
//  Copyright © 2018 breadwallet LLC. All rights reserved.
//

import XCTest
@testable import breadwallet

import BRCore

private let testPrivKey = "a1a8cae79e17cb4ddb4fb6871fcc87f3ee5cbb1049a168657d2c3493d79bfa16"
private let testPrivKey2 = "a1a8cae79e17cb4ddb4fb6871fcc87f3ee5cbb1049a168657d2c3493d79bfa17"
private let testPubKey = "02d404943960a71535a79679f1cf1df80e70597c05b05722839b38ebc8803af517".hexToData!
private let sampleInputData = "b5647811e4472f3ebbadaa9812807785c7ebc04e36d3b6508af7494068fba174".hexToData!

class PigeonTests : XCTestCase {

    private let crypto = PigeonCrypto(privateKey: BRKey(privKey: testPrivKey)!)

    func testEncryptDecrypt() {
        let (encryptedData, nonce) = crypto.encrypt(sampleInputData, receiverPublicKey: testPubKey)
        let decryptedData = crypto.decrypt(encryptedData, nonce: nonce, senderPublicKey: testPubKey)
        XCTAssert(decryptedData.hexString == sampleInputData.hexString)
    }

    func testSignVerify() {
        var randomBytes: [UInt8] = [UInt8](repeating: 0, count: 65)
        guard SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes) == 0
            else { return XCTAssert(false) }
        let data = Data(randomBytes)
        let signature = crypto.sign(data: data)
        XCTAssert(crypto.verify(data: data, signature: signature, pubKey: BRKey(privKey: testPrivKey)!.publicKey))
    }

    func testConstructDeconstruct() {
        let senderKey = BRKey(privKey: testPrivKey)!
        let receiverKey = BRKey(privKey: testPrivKey2)!
        var ping = MessagePing()
        ping.ping = "Hi Sam"
        guard let envelope = try? MessageEnvelope(to: receiverKey.publicKey, from: senderKey.publicKey, message: ping, type: .ping, crypto: crypto) else { return XCTFail() }
        XCTAssert(envelope.verify(pairingKey: receiverKey), "Envelope should pass verification")
        let receiverCrypto = PigeonCrypto(privateKey: receiverKey)
        let decryptedData = receiverCrypto.decrypt(envelope.encryptedMessage, nonce: envelope.nonce, senderPublicKey: senderKey.publicKey)
        if let deconstructedPing = try? MessagePing(serializedData: decryptedData) {
            XCTAssert(deconstructedPing.ping == "Hi Sam")
        } else {
            XCTAssert(false, "Failed to deconstruct message")
        }
    }

    func testVerifyEnvelope() {
        let localPairingKey = BRKey(privKey: testPrivKey)!
        let remotePairingKey = BRKey(privKey: testPrivKey2)!
        var ping = MessagePing()
        ping.ping = "Hi Sam"
        guard let envelope = try? MessageEnvelope(to: remotePairingKey.publicKey, from: localPairingKey.publicKey, message: ping, type: .ping, crypto: crypto) else { return XCTFail() }
        XCTAssert(envelope.verify(pairingKey: remotePairingKey), "Envelope should pass verification")
    }

}
