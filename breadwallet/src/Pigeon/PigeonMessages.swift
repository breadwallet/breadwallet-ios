//
//  PigeonMessages.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2018-07-17.
//  Copyright © 2018-2019 Breadwinner AG. All rights reserved.
//

import Foundation
import SwiftProtobuf
import BRCrypto

enum PigeonMessageType: String {
    case link = "LINK"
    case ping = "PING"
    case pong = "PONG"
    case accountRequest = "ACCOUNT_REQUEST"
    case accountResponse = "ACCOUNT_RESPONSE"
    case paymentRequest = "PAYMENT_REQUEST"
    case paymentResponse = "PAYMENT_RESPONSE"
    case callRequest = "CALL_REQUEST"
    case callResponse = "CALL_RESPONSE"
}

extension MessageEnvelope {

    /// Create an envelope for a new message to the specified public key.
    init(to receiverPubKey: Data, from senderPubKey: Data, message: SwiftProtobuf.Message, type: PigeonMessageType, service: String, crypto: PigeonCrypto) throws {
        self.init()

        self.version = 1
        self.service = service
        self.messageType = type.rawValue
        self.senderPublicKey = senderPubKey
        self.receiverPublicKey = receiverPubKey
        self.identifier = UUID().uuidString

        guard let (encryptedMessageData, nonce) = crypto.encrypt(try message.serializedData(), receiverPublicKey: receiverPubKey) else {
            throw PigeonCrypto.CryptoError.encryptError
        }
        self.encryptedMessage = encryptedMessageData
        self.nonce = nonce
        self.signature = Data()
        let envelopeData = try self.serializedData()
        guard let signature = crypto.sign(data: envelopeData) else {
            throw PigeonCrypto.CryptoError.encryptError
        }
        self.signature = signature
    }
    
    /// Creates a response envelope to reply to a request envelope. The sender/receiver public keys of the request envelope will be used as the receiver/sender of new envelope.
    init(replyTo requestEnvelope: MessageEnvelope, message: SwiftProtobuf.Message, type: PigeonMessageType, crypto: PigeonCrypto) throws {
        self.init()
        
        self.version = 1
        self.service = requestEnvelope.service
        self.messageType = type.rawValue
        self.senderPublicKey = requestEnvelope.receiverPublicKey
        self.receiverPublicKey = requestEnvelope.senderPublicKey
        self.identifier = requestEnvelope.identifier
        
        guard let (encryptedMessageData, nonce) = crypto.encrypt(try message.serializedData(), receiverPublicKey: receiverPublicKey) else {
            throw PigeonCrypto.CryptoError.encryptError
        }
        self.encryptedMessage = encryptedMessageData
        self.nonce = nonce
        self.signature = Data()
        let envelopeData = try self.serializedData()
        guard let signature = crypto.sign(data: envelopeData) else {
            throw PigeonCrypto.CryptoError.encryptError
        }
        self.signature = signature
    }
    
    func verify(pairingKey: Key) -> Bool {
        guard pairingKey.encodeAsPublic == receiverPublicKey.hexString else { return false }
        guard !self.signature.isEmpty else { return false }
        let crypto = PigeonCrypto(privateKey: pairingKey)
        var envelope = self
        envelope.signature = Data()
        guard let data = try? envelope.serializedData() else { return false }
        return crypto.verify(data: data, signature: self.signature, pubKey: envelope.senderPublicKey)
    }
}

extension InboxEntry {
    var envelope: MessageEnvelope? {
        guard let messageData = Data(base64Encoded: message) else { return nil }
        do {
            let envelope = try MessageEnvelope(serializedData: messageData)
            return envelope
        } catch let decodeError {
            print("[EME] envelope decode error: \(decodeError)")
            return nil
        }
    }
}
