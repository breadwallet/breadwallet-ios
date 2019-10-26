//
//  PigeonCrypto.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2018-07-16.
//  Copyright © 2018-2019 Breadwinner AG. All rights reserved.
//
import Foundation
import BRCrypto

struct PigeonCrypto {
    
    enum CryptoError: Error {
        case encryptError
        case decryptError
        case signError
    }

    /// Pairing key associated with the remote entity
    private let privateKey: Key

    init(privateKey: Key) {
        self.privateKey = privateKey
    }
    
    /// Generates a pairing key for the identifier string and returns the DER-encoded public key
    static func pairingKey(forIdentifier identifier: String, authKey: Key) -> Key? {
        guard let identifierData = identifier.data(using: .utf8),
            let remoteIdentifier = identifierData.sha256.hexString.hexToData else { return nil }
        let nonce = Array(remoteIdentifier)
        return Key.createForPigeonFrom(key: authKey, nonce: Data(nonce))
    }
    
    func decrypt(_ data: Data, nonce: Data, senderPublicKey: Data) -> Data? {
        guard let pubKey = Key.createFromString(asPublic: senderPublicKey.hexString) else {
            assertionFailure()
            return nil
        }
        let decrypter = CoreCipher.pigeon(privKey: privateKey,
                                          pubKey: pubKey,
                                          nonce12: nonce)
        return decrypter.decrypt(data: data)
    }
    
    /// Returns (encryptedData, nonce) - the nonce is needed to be attached to the envelope
    func encrypt(_ data: Data, receiverPublicKey: Data) -> (Data, Data)? {
        guard let pubKey = Key.createFromString(asPublic: receiverPublicKey.hexString) else {
            assertionFailure()
            return (Data(), Data())
        }
        let nonce = Data(genNonce())
        let encrypter = CoreCipher.pigeon(privKey: privateKey,
                                          pubKey: pubKey,
                                          nonce12: nonce)
        if let outData = encrypter.encrypt(data: data) {
            return (outData, Data(nonce))
        } else {
            return nil
        }
    }

    func sign(data: Data) -> Data? {
        return data.sha256_2.compactSign(key: privateKey)
    }

    func verify(data: Data, signature: Data, pubKey: Data) -> Bool {
        guard !signature.isEmpty else { return false }
        guard let recoveredKey = CoreSigner.compact.recover(data32: data.sha256_2, signature: signature) else { return false }
        return pubKey.hexString == recoveredKey.encodeAsPublic
    }

    private func genNonce() -> [UInt8] {
        var randomBytes: [UInt8] = [UInt8](repeating: 0, count: 12)
        guard SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes) == 0 else { assertionFailure(); return [] }
        return randomBytes
    }
}
