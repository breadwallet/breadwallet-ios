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

extension NSNotification.Name {
    public static let WalletDidWipe = NSNotification.Name("WalletDidWipe")
}

protocol WalletManager: class {
    var currency: Currency { get }
    var peerManager: BRPeerManager? { get }
    var wallet: BRWallet? { get }
    var kvStore: BRReplicatedKVStore? { get set }
    
    func resetForWipe()
    func canUseBiometrics(forTx: BRTxRef) -> Bool
    func isOwnAddress(_ address: String) -> Bool
}

// MARK: - Wallet
extension WalletManager {

    var peerManager: BRPeerManager? { return nil }
    var wallet: BRWallet? { return nil }
    
    func isOwnAddress(_ address: String) -> Bool {
        return wallet?.containsAddress(address) ?? false
    }
}

// MARK: - Phrases
private struct AssociatedKeys {
    static var allWordsLists = "allWordsLists"
    static var allWords = "allWords"
}

extension WalletManager {
    var allWordsLists: [[NSString]] {
        guard let array = objc_getAssociatedObject(self, &AssociatedKeys.allWordsLists) as? [[NSString]]  else {
            var array: [[NSString]] = []
            addWords { array.append($0) }
            objc_setAssociatedObject(self, &AssociatedKeys.allWordsLists, array, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            return array
        }
        return array
    }

    var allWords: Set<String> {
        guard let array = objc_getAssociatedObject(self, &AssociatedKeys.allWords) as? Set<String>  else {
            var set: Set<String> = Set()
            addWords { set.formUnion($0.map { $0 as String }) }
            objc_setAssociatedObject(self, &AssociatedKeys.allWords, set, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            return set
        }
        return array
    }

    private func addWords(callback: (([NSString]) -> Void)) {
        Bundle.main.localizations.forEach { lang in
            if let path = Bundle.main.path(forResource: "BIP39Words", ofType: "plist", inDirectory: nil, forLocalization: lang) {
                if let words = NSArray(contentsOfFile: path) as? [NSString] {
                    callback(words)
                }
            }
        }
    }

    func isPhraseValid(_ phrase: String) -> Bool {
        for wordList in allWordsLists {
            var words = wordList.map({ $0.utf8String })
            guard let nfkdPhrase = CFStringCreateMutableCopy(secureAllocator, 0, phrase as CFString) else { return false }
            CFStringNormalize(nfkdPhrase, .KD)
            if BRBIP39PhraseIsValid(&words, nfkdPhrase as String) != 0 {
                return true
            }
        }
        return false
    }

    func isWordValid(_ word: String) -> Bool {
        return allWords.contains(word)
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
        //TODO: notifications
//        UIApplication.shared.applicationIconBadgeNumber = UIApplication.shared.applicationIconBadgeNumber + 1
//        let notification = UILocalNotification()
//        notification.alertBody = message
//        notification.soundName = "coinflip.aiff"
//        UIApplication.shared.presentLocalNotificationNow(notification)
    }
}
