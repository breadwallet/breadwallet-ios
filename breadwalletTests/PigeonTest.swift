//
//  PigeonTests.swift
//  breadwalletTests
//
//  Created by Adrian Corscadden on 2018-07-16.
//  Copyright © 2018-2019 Breadwinner AG. All rights reserved.
//

import XCTest
@testable import breadwallet

import BRCrypto

private let testPrivKey = "a1a8cae79e17cb4ddb4fb6871fcc87f3ee5cbb1049a168657d2c3493d79bfa16"
private let testPrivKey2 = "a1a8cae79e17cb4ddb4fb6871fcc87f3ee5cbb1049a168657d2c3493d79bfa17"
private let testPubKey = "02d404943960a71535a79679f1cf1df80e70597c05b05722839b38ebc8803af517".hexToData!
private let sampleInputData = "b5647811e4472f3ebbadaa9812807785c7ebc04e36d3b6508af7494068fba174".hexToData!

class PigeonTests : XCTestCase {

    private lazy var crypto: PigeonCrypto? = {
        guard let key = Key.createFromString(asPrivate: testPrivKey) else {
            return nil
        }
        return PigeonCrypto(privateKey: key)
    }()

    func testEncryptDecrypt() {
        guard let crypto = crypto else { return XCTFail() }
        guard let (encryptedData, nonce) = crypto.encrypt(sampleInputData, receiverPublicKey: testPubKey) else { return XCTFail() }
        guard let decryptedData = crypto.decrypt(encryptedData, nonce: nonce, senderPublicKey: testPubKey) else { return XCTFail() }
        XCTAssertEqual(decryptedData.hexString, sampleInputData.hexString)
    }

    func testSignVerify() {
        guard let crypto = crypto else { return XCTFail() }
        var randomBytes: [UInt8] = [UInt8](repeating: 0, count: 65)
        guard SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes) == 0
            else { return XCTAssert(false) }
        let data = Data(randomBytes)
        guard let signature = crypto.sign(data: data) else { return XCTFail() }
        guard let pubKey = Key.createFromString(asPrivate: testPrivKey)?.encodeAsPublic.hexToData else { return XCTFail() }
        XCTAssert(crypto.verify(data: data, signature: signature, pubKey: pubKey))
    }

    func testConstructDeconstruct() {
        guard let crypto = crypto else { return XCTFail() }
        guard let senderKey = Key.createFromString(asPrivate: testPrivKey),
            let receiverKey = Key.createFromString(asPrivate: testPrivKey2) else {
            return XCTFail()
        }
        guard let senderPubKey = senderKey.encodeAsPublic.hexToData,
            let receiverPubKey = receiverKey.encodeAsPublic.hexToData else {
                return XCTFail()
        }
        var ping = MessagePing()
        ping.ping = "Hi Sam"
        guard let envelope = try? MessageEnvelope(to: receiverPubKey,
                                                  from: senderPubKey,
                                                  message: ping,
                                                  type: .ping,
                                                  service: "PWB",
                                                  crypto: crypto) else { return XCTFail() }
        XCTAssert(envelope.verify(pairingKey: receiverKey), "Envelope should pass verification")
        let receiverCrypto = PigeonCrypto(privateKey: receiverKey)
        guard let decryptedData = receiverCrypto.decrypt(envelope.encryptedMessage,
                                                   nonce: envelope.nonce,
                                                   senderPublicKey: senderPubKey) else { return XCTFail() }
        if let deconstructedPing = try? MessagePing(serializedData: decryptedData) {
            XCTAssert(deconstructedPing.ping == "Hi Sam")
        } else {
            XCTFail("Failed to deconstruct message")
        }
    }

    func testVerifyEnvelope() {
        guard let crypto = crypto else { return XCTFail() }
        guard let localPairingKey = Key.createFromString(asPrivate: testPrivKey),
            let remotePairingKey = Key.createFromString(asPrivate: testPrivKey2) else {
                return XCTFail()
        }
        guard let remotePubKey = remotePairingKey.encodeAsPublic.hexToData,
            let localPubKey = localPairingKey.encodeAsPublic.hexToData else {
                return XCTFail()
        }
        var ping = MessagePing()
        ping.ping = "Hi Sam"
        guard let envelope = try? MessageEnvelope(to: remotePubKey,
                                                  from: localPubKey,
                                                  message: ping,
                                                  type: .ping,
                                                  service: "PWB",
                                                  crypto: crypto) else { return XCTFail() }
        XCTAssert(envelope.verify(pairingKey: remotePairingKey), "Envelope should pass verification")
    }

}
