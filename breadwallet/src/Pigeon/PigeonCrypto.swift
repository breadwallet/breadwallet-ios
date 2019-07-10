//
//  PigeonCrypto.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2018-07-16.
//  Copyright © 2018-2019 Breadwinner AG. All rights reserved.
//
import Foundation
import BRCore

struct PigeonCrypto {

    /// Pairing key associated with the remote entity
    private let privateKey: BRKey

    init(privateKey: BRKey) {
        self.privateKey = privateKey
    }
    
    /// Generates a pairing key for the identifier string and returns the DER-encoded public key
    static func pairingKey(forIdentifier identifier: String, authKey: BRKey) -> BRKey? {
        guard let identifierData = identifier.data(using: .utf8),
            let remoteIdentifier = identifierData.sha256.hexString.hexToData else { return nil }

        let nonce = Array(remoteIdentifier)
        var privKey = authKey
        var pairingKey = BRKey()
        BRKeyPigeonPairingKey(&privKey, &pairingKey, nonce, nonce.count)
        return pairingKey
    }

    func decrypt(_ data: Data, nonce: Data, senderPublicKey: Data) -> Data {
        let nonce = Array(nonce)
        let inData = Array(data)
        var privKey = self.privateKey
        var pubKey = BRKey(pubKey: [UInt8](senderPublicKey))!
        let outSize = BRKeyPigeonDecrypt(nil, nil, 0, nil, nonce, inData, inData.count)
        var outData = [UInt8](repeating: 0, count: outSize)
        BRKeyPigeonDecrypt(&privKey, &outData, outSize, &pubKey, nonce, inData, inData.count)
        return Data(outData)
    }

    /// Returns (encryptedData, nonce) - the nonce is needed to be attached to the envelope
    func encrypt(_ data: Data, receiverPublicKey: Data) -> (Data, Data) {
        let inData = Array(data)
        let nonce = genNonce()
        var privKey = self.privateKey
        var pubKey = BRKey(pubKey: [UInt8](receiverPublicKey))!
        let outSize = BRKeyPigeonEncrypt(nil, nil, 0, nil, nonce, inData, inData.count)
        var outData = [UInt8](repeating: 0, count: outSize)
        BRKeyPigeonEncrypt(&privKey, &outData, outSize, &pubKey, nonce, inData, data.count)
        return (Data(outData), Data(nonce))
    }

    func sign(data: Data) -> Data {
        return data.sha256_2.compactSign(key: privateKey)
    }

    func verify(data: Data, signature: Data, pubKey: Data) -> Bool {
        guard let recoveredKey = BRKey(md: data.sha256_2.uInt256, compactSig: [UInt8](signature)) else { return false }
        return pubKey.hexString == recoveredKey.publicKey.hexString
    }

    private func genNonce() -> [UInt8] {
        var randomBytes: [UInt8] = [UInt8](repeating: 0, count: 12)
        guard SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes) == 0 else { assertionFailure(); return [] }
        return randomBytes
    }
}
