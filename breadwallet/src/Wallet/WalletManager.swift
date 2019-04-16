//
//  WalletManager.swift
//  breadwallet
//
//  Created by Aaron Voisine on 10/13/16.
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
import AVFoundation
import BRCore

// MARK: - Wallet

protocol WalletManager: class {
    var currency: Currency { get }
//    var peerManager: BRPeerManager? { get }
//    var wallet: BRWallet? { get }
    var kvStore: BRReplicatedKVStore? { get set }
    var isConnected: Bool { get }

    func connect()
    func disconnect()
    func resetForWipe()
    func isOwnAddress(_ address: String) -> Bool
}

extension WalletManager {

//    var peerManager: BRPeerManager? { return nil }
//    var wallet: BRWallet? { return nil }

    func isOwnAddress(_ address: String) -> Bool {
        return false //TODO:CRYPTO
        //return wallet?.containsAddress(address) ?? false
    }
}

// MARK: - Sounds
extension WalletManager {
    func ping() {
        guard let url = Bundle.main.url(forResource: "coinflip", withExtension: "aiff") else { return }
        var id: SystemSoundID = 0
        AudioServicesCreateSystemSoundID(url as CFURL, &id)
        AudioServicesAddSystemSoundCompletion(id, nil, nil, { soundId, _ in
            AudioServicesDisposeSystemSoundID(soundId)
        }, nil)
        AudioServicesPlaySystemSound(id)
    }

    func showLocalNotification(message: String) {
        guard UIApplication.shared.applicationState == .background || UIApplication.shared.applicationState == .inactive else { return }
        guard Store.state.isPushNotificationsEnabled else { return }
    }
}
