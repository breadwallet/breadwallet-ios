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
import SystemConfiguration
import BRCore

extension NSNotification.Name {
    public static let WalletBalanceChangedNotification = NSNotification.Name("WalletBalanceChanged")
    public static let WalletTxStatusUpdateNotification = NSNotification.Name("WalletTxStatusUpdate")
    public static let WalletTxRejectedNotification = NSNotification.Name("WalletTxRejected")
    public static let WalletSyncStartedNotification = NSNotification.Name("WalletSyncStarted")
    public static let WalletSyncStoppedNotification = NSNotification.Name("WalletSyncStopped")
    public static let WalletDidWipe = NSNotification.Name("WalletDidWipe")
}

// A WalletManger instance manages a single wallet, and that wallet's individual connection to the bitcoin network.
// After instantiating a WalletManager object, call myWalletManager.peerManager.connect() to begin syncing.

class WalletManager : BRWalletListener, BRPeerManagerListener {
    private let currency: CurrencyDef
    internal var didInitWallet = false
    var masterPubKey = BRMasterPubKey()
    var earliestKeyTime: TimeInterval = 0
    var db: CoreDatabase?
    var wallet: BRWallet?

    func initWallet(callback: @escaping (Bool) -> Void) {
        db?.loadTransactions { txns in
            guard self.masterPubKey != BRMasterPubKey() else {
                #if !Debug
                    self.db?.delete()
                #endif
                return callback(false)
            }
            self.wallet = BRWallet(transactions: txns, masterPubKey: self.masterPubKey, listener: self)
            callback(self.wallet != nil)
        }
    }

    func initPeerManager(callback: @escaping () -> Void) {
        db?.loadBlocks { [weak self] blocks in
            guard let myself = self else { return }
            myself.db?.loadPeers { peers in
                guard let wallet = myself.wallet else { return }
                myself.peerManager = BRPeerManager(currency: myself.currency, wallet: wallet, earliestKeyTime: myself.earliestKeyTime,
                                                 blocks: blocks, peers: peers, listener: myself)
                callback()
            }
        }
    }
    
    var apiClient: BRAPIClient? {
        guard self.masterPubKey != BRMasterPubKey() else { return nil }
        return lazyAPIClient
    }

    var peerManager: BRPeerManager?

    internal lazy var bCashWallet: BRWallet? = {
        guard let wallet = self.wallet else { return nil }
        let txns = wallet.transactions.flatMap { return $0 } .filter { $0.pointee.blockHeight < bCashForkBlockHeight }
        return BRWallet(transactions: txns, masterPubKey: self.masterPubKey, listener: BadListener())
    }()

    private lazy var lazyAPIClient: BRAPIClient? = {
        guard let wallet = self.wallet else { return nil }
        return BRAPIClient(authenticator: self)
    }()

    var wordList: [NSString]? {
        guard let path = Bundle.main.path(forResource: "BIP39Words", ofType: "plist") else { return nil }
        return NSArray(contentsOfFile: path) as? [NSString]
    }

    lazy var allWordsLists: [[NSString]] = {
        var array: [[NSString]] = []
        Bundle.main.localizations.forEach { lang in
            if let path = Bundle.main.path(forResource: "BIP39Words", ofType: "plist", inDirectory: nil, forLocalization: lang) {
                if let words = NSArray(contentsOfFile: path) as? [NSString] {
                    array.append(words)
                }
            }
        }
        return array
    }()

    lazy var allWords: Set<String> = {
        var set: Set<String> = Set()
        Bundle.main.localizations.forEach { lang in
            if let path = Bundle.main.path(forResource: "BIP39Words", ofType: "plist", inDirectory: nil, forLocalization: lang) {
                if let words = NSArray(contentsOfFile: path) as? [NSString] {
                    set.formUnion(words.map { $0 as String })
                }
            }
        }
        return set
    }()

    var rawWordList: [UnsafePointer<CChar>?]? {
        guard let wordList = wordList, wordList.count == 2048 else { return nil }
        return wordList.map({ $0.utf8String })
    }

    init(currency: CurrencyDef, masterPubKey: BRMasterPubKey, earliestKeyTime: TimeInterval, dbPath: String? = nil) throws {
        self.currency = currency
        self.masterPubKey = masterPubKey
        self.earliestKeyTime = earliestKeyTime
        if let path = dbPath {
            self.db = CoreDatabase(dbPath: path)
        } else {
            self.db = CoreDatabase()
        }
    }
    
    func balanceChanged(_ balance: UInt64) {
        DispatchQueue.main.async() {
            NotificationCenter.default.post(name: .WalletBalanceChangedNotification, object: nil,
                                            userInfo: ["balance": balance])
        }
    }
    
    func txAdded(_ tx: BRTxRef) {
        db?.txAdded(tx)
    }
    
    func txUpdated(_ txHashes: [UInt256], blockHeight: UInt32, timestamp: UInt32) {
        db?.txUpdated(txHashes, blockHeight: blockHeight, timestamp: timestamp)
    }
    
    func txDeleted(_ txHash: UInt256, notifyUser: Bool, recommendRescan: Bool) {
        db?.txDeleted(txHash, notifyUser: notifyUser, recommendRescan: true)
    }

    func syncStarted() {
        DispatchQueue.main.async() {
            self.db?.setDBFileAttributes()
            NotificationCenter.default.post(name: .WalletSyncStartedNotification, object: nil)
        }
    }
    
    func syncStopped(_ error: BRPeerManagerError?) {
        switch error {
        case .some(let .posixError(errorCode, description)):
            DispatchQueue.main.async() {
                NotificationCenter.default.post(name: .WalletSyncStoppedNotification, object: nil,
                                                userInfo: ["errorCode": errorCode,
                                                           "errorDescription": description])
            }
        case .none:
            DispatchQueue.main.async() {
                NotificationCenter.default.post(name: .WalletSyncStoppedNotification, object: nil)
            }
        }
    }
    
    func txStatusUpdate() {
        DispatchQueue.main.async() {
            NotificationCenter.default.post(name: .WalletTxStatusUpdateNotification, object: nil)
        }
    }
    
    func saveBlocks(_ replace: Bool, _ blocks: [BRBlockRef?]) {
        db?.saveBlocks(replace, blocks)
    }
    
    func savePeers(_ replace: Bool, _ peers: [BRPeer]) {
        db?.savePeers(replace, peers)
    }
    
    func networkIsReachable() -> Bool {
        var flags: SCNetworkReachabilityFlags = []
        var zeroAddress = sockaddr()
        zeroAddress.sa_len = UInt8(MemoryLayout<sockaddr>.size)
        zeroAddress.sa_family = sa_family_t(AF_INET)
        guard let reachability = SCNetworkReachabilityCreateWithAddress(nil, &zeroAddress) else { return false }
        if !SCNetworkReachabilityGetFlags(reachability, &flags) { return false }
        return flags.contains(.reachable) && !flags.contains(.connectionRequired)
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

    var isWatchOnly: Bool {
        let mpkData = Data(masterPubKey: masterPubKey)
        return mpkData.count == 0
    }

}
