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
import SystemConfiguration
import BRCore
import BRCore.Ethereum
import AVFoundation

extension NSNotification.Name {
    public static let WalletDidWipe = NSNotification.Name("WalletDidWipe")
}

// A WalletManger instance manages a single wallet, and that wallet's individual connection to the bitcoin network.
// After instantiating a WalletManager object, call myWalletManager.peerManager.connect() to begin syncing.

protocol WalletManager {
    var currency: CurrencyDef { get }
    func resetForWipe()
    var peerManager: BRPeerManager? { get }
    var wallet: BRWallet? { get }
    var kvStore: BRReplicatedKVStore? { get set }
    var apiClient: BRAPIClient? { get }
    func canUseBiometrics(forTx: BRTxRef) -> Bool
}

class EthWalletManager : WalletManager {
    var peerManager: BRPeerManager?
    var wallet: BRWallet?
    var currency: CurrencyDef = Currencies.eth
    var kvStore: BRReplicatedKVStore?
    var apiClient: BRAPIClient?
    var address: String?

    var ethAddress: BREthereumAddress?
    var account: BREthereumAccount?
    var ethWallet: BREthereumWallet?
    private var timer: Timer? = nil
    private let updateInterval: TimeInterval = 5
    private var pendingTransactions = [EthTx]()

    init() {
        guard var words = Words.rawWordList else { return }
        installSharedWordList(&words, Int32(words.count))
        self.account = createAccount(loadPhrase())
        self.ethAddress = accountGetPrimaryAddress(self.account)
        self.ethWallet = walletCreate(account, E.isTestnet ? ethereumTestnet : ethereumMainnet)
        if let address = addressAsString(self.ethAddress) {
            if let address = String(cString: address, encoding: .utf8) {
                self.address = address
                Store.perform(action: WalletChange(self.currency).set(self.currency.state.mutate(receiveAddress: address)))
            }
        }
        DispatchQueue.main.async { [weak self] in
            guard let myself = self else { return }
            myself.timer = Timer.scheduledTimer(timeInterval: myself.updateInterval, target: myself, selector: #selector(myself.refresh), userInfo: nil, repeats: true)
        }
    }

    @objc private func refresh() {
        updateBalance()
        updateTransactionList()
    }
    
    func updateBalance() {
        apiClient?.getBalance(address: address!, handler: { result in
            switch result {
            case .success(let value):
                Store.perform(action: WalletChange(self.currency).setBalance(value))
            case .error(let error):
                print("getBalance error: \(error.localizedDescription)")
            }
        })
    }

    func updateTransactionList() {
        apiClient?.getEthTxList(address: self.address!, handler: { [weak self] txList in
            guard let `self` = self else { return }
            for tx in txList {
                if let index = self.pendingTransactions.index(where: { $0.hash == tx.hash }) {
                    self.pendingTransactions.remove(at: index)
                }
            }
            let transactions = (self.pendingTransactions + txList).map { EthTransaction(tx: $0, address: self.address!) }
            DispatchQueue.main.async {
                Store.perform(action: WalletChange(self.currency).setTransactions(transactions))
            }
        })
    }

    func sendTx(toAddress: String, amount: UInt256, callback: @escaping (JSONRPCResult<String>)->Void) {
        //TODO:ETH - add authentication
        let ethToAddress = createAddress(toAddress)
        let ethAmount = amountCreateEther((etherCreate(amount)))
        let gasPrice = gasPriceCreate((etherCreate(UInt256(22000000000))))
        let gasLimit = gasCreate(UInt64(21000))
        let nonce = Int32(Store.state.wallets[currency.code]!.transactions.filter { $0.direction == .sent }.count)
        let tx = walletCreateTransactionDetailed(ethWallet, ethToAddress, ethAmount, gasPrice, gasLimit, UInt64(nonce))
        walletSignTransaction(ethWallet, tx, loadPhrase())
        let txString = walletGetRawTransactionHexEncoded(ethWallet, tx, "0x")
        apiClient?.sendRawTransaction(rawTx: String(cString: txString!, encoding: .utf8)!, handler: { [weak self] result in
            guard let `self` = self else { return }
            if case .success(let txHash) = result {
                let pendingTx = EthTx(blockNumber: 0,
                                      timeStamp: Date().timeIntervalSince1970,
                                      value: amount,
                                      gasPrice: gasPrice.etherPerGas.valueInWEI,
                                      gasLimit: gasLimit.amountOfGas,
                                      gasUsed: 0,
                                      from: self.address!,
                                      to: toAddress,
                                      confirmations: 0,
                                      nonce: UInt64(nonce),
                                      hash: txHash,
                                      isError: false)
                self.pendingTransactions.append(pendingTx)
            }
            callback(result)
        })
    }

    func resetForWipe() {
        return
    }

    func canUseBiometrics(forTx: BRTxRef) -> Bool {
        return false
    }
}

class BTCWalletManager : WalletManager {
    let currency: CurrencyDef
    var masterPubKey = BRMasterPubKey()
    var earliestKeyTime: TimeInterval = 0
    var db: CoreDatabase?
    var wallet: BRWallet?
    private let progressUpdateInterval: TimeInterval = 0.5
    private let updateDebounceInterval: TimeInterval = 0.4
    private var progressTimer: Timer?
    private var lastBlockHeightKey: String {
        return "LastBlockHeightKey-\(currency.code)"
    }
    private var lastBlockHeight: UInt32 {
        set { UserDefaults.standard.set(newValue, forKey: lastBlockHeightKey) }
        get { return UInt32(UserDefaults.standard.integer(forKey: lastBlockHeightKey)) }
    }
    private var retryTimer: RetryTimer?
    private var updateTimer: Timer?
    var kvStore: BRReplicatedKVStore? {
        didSet { requestTxUpdate() }
    }
    
    func initWallet(callback: @escaping (Bool) -> Void) {
        db?.loadTransactions { txns in
            guard self.masterPubKey != BRMasterPubKey() else {
                #if !Debug
                    self.db?.delete()
                #endif
                return callback(false)
            }
            self.wallet = BRWallet(transactions: txns, masterPubKey: self.masterPubKey, listener: self)
            if let wallet = self.wallet {
                Store.perform(action: WalletChange(self.currency).setBalance(UInt256(wallet.balance)))
                Store.perform(action: WalletChange(self.currency).set(self.currency.state.mutate(receiveAddress: wallet.receiveAddress)))
            }
            callback(self.wallet != nil)
        }
    }

    func initWallet(transactions: [BRTxRef]) {
        guard self.masterPubKey != BRMasterPubKey() else {
            #if !Debug
                self.db?.delete()
            #endif
            return
        }
        self.wallet = BRWallet(transactions: transactions, masterPubKey: self.masterPubKey, listener: self)
        if let wallet = self.wallet {
            Store.perform(action: WalletChange(self.currency).setBalance(UInt256(wallet.balance)))
            Store.perform(action: WalletChange(self.currency).set(self.currency.state.mutate(receiveAddress: wallet.receiveAddress)))
        }
    }

    func initPeerManager(blocks: [BRBlockRef?]) {
        guard let wallet = self.wallet else { return }
        self.peerManager = BRPeerManager(currency: currency, wallet: wallet, earliestKeyTime: earliestKeyTime,
                                          blocks: blocks, peers: [], listener: self)
    }

    func initPeerManager(callback: @escaping () -> Void) {
        db?.loadBlocks { [unowned self] blocks in
            self.db?.loadPeers { peers in
                guard let wallet = self.wallet else { return }
                self.peerManager = BRPeerManager(currency: self.currency, wallet: wallet, earliestKeyTime: self.earliestKeyTime,
                                                 blocks: blocks, peers: peers, listener: self)
                callback()
            }
        }
    }
    
    var apiClient: BRAPIClient? {
        guard self.masterPubKey != BRMasterPubKey() else { return nil }
        return lazyAPIClient
    }

    var peerManager: BRPeerManager?

    private lazy var lazyAPIClient: BRAPIClient? = {
        guard let wallet = self.wallet else { return nil }
        return BRAPIClient(authenticator: self)
    }()

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

extension BTCWalletManager : BRPeerManagerListener, Trackable {

    func syncStarted() {
        DispatchQueue.main.async() {
            self.db?.setDBFileAttributes()
            self.progressTimer = Timer.scheduledTimer(timeInterval: self.progressUpdateInterval, target: self, selector: #selector(self.updateProgress), userInfo: nil, repeats: true)
            Store.perform(action: WalletChange(self.currency).setSyncingState(.syncing))
        }
    }

    func syncStopped(_ error: BRPeerManagerError?) {
        DispatchQueue.main.async() {
            if UIApplication.shared.applicationState != .active {
                DispatchQueue.walletQueue.async {
                    self.peerManager?.disconnect()
                }
                return
            }

            switch error {
            case .some(let .posixError(errorCode, description)):

                Store.perform(action: WalletChange(self.currency).setSyncingState(.connecting))
                self.saveEvent("event.syncErrorMessage", attributes: ["message": "\(description) (\(errorCode))"])
                if self.retryTimer == nil && self.networkIsReachable() {
                    self.retryTimer = RetryTimer()
                    self.retryTimer?.callback = strongify(self) { myself in
                        Store.trigger(name: .retrySync(self.currency))
                    }
                    self.retryTimer?.start()
                }
            case .none:
                self.retryTimer?.stop()
                self.retryTimer = nil
                if let height = self.peerManager?.lastBlockHeight {
                    self.lastBlockHeight = height
                }
                self.progressTimer?.invalidate()
                self.progressTimer = nil
                Store.perform(action: WalletChange(self.currency).setSyncingState(.success))
            }
        }
    }

    func txStatusUpdate() {
        DispatchQueue.main.async { [weak self] in
            self?.requestTxUpdate()
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

    @objc private func updateProgress() {
        DispatchQueue.walletQueue.async {
            guard let progress = self.peerManager?.syncProgress(fromStartHeight: self.lastBlockHeight), let timestamp = self.peerManager?.lastBlockTimestamp else { return }
            DispatchQueue.main.async {
                Store.perform(action: WalletChange(self.currency).setProgress(progress: progress, timestamp: timestamp))
                if let wallet = self.wallet {
                    Store.perform(action: WalletChange(self.currency).setBalance(UInt256(wallet.balance)))
                }
            }
        }
    }
}

extension BTCWalletManager : BRWalletListener {
    func balanceChanged(_ balance: UInt64) {
        DispatchQueue.main.async { [weak self] in
            guard let myself = self else { return }
            myself.checkForReceived(newBalance: balance)
            Store.perform(action: WalletChange(myself.currency).setBalance(UInt256(balance)))
            myself.requestTxUpdate()
        }
    }

    func txAdded(_ tx: BRTxRef) {
        db?.txAdded(tx)
    }

    func txUpdated(_ txHashes: [UInt256], blockHeight: UInt32, timestamp: UInt32) {
        db?.txUpdated(txHashes, blockHeight: blockHeight, timestamp: timestamp)
    }

    func txDeleted(_ txHash: UInt256, notifyUser: Bool, recommendRescan: Bool) {
        if notifyUser {
            if recommendRescan {
                DispatchQueue.main.async { [weak self] in
                    guard let myself = self else { return }
                    Store.perform(action: WalletChange(myself.currency).setRecommendScan(recommendRescan)) }
            }
        }
        DispatchQueue.main.async { [weak self] in
            self?.requestTxUpdate()
        }
        db?.txDeleted(txHash, notifyUser: notifyUser, recommendRescan: true)
    }

    private func checkForReceived(newBalance: UInt64) {
        //TODO:ETH
        if let oldBalance = currency.state.balance?.asUInt64 {
            if newBalance > oldBalance {
                let walletState = currency.state
                Store.perform(action: WalletChange(currency).set(walletState.mutate(receiveAddress: wallet?.receiveAddress)))
                if currency.state.syncState == .success {
                    showReceived(amount: newBalance - oldBalance)
                }
            }
        }
    }

    private func showReceived(amount: UInt64) {
        if let rate = currency.state.currentRate {
            let tokenAmount = Amount(amount: UInt256(amount),
                                     currency: currency,
                                     rate: nil,
                                     minimumFractionDigits: 0)
            let fiatAmount = Amount(amount: UInt256(amount),
                                    currency: currency,
                                    rate: rate,
                                    minimumFractionDigits: 0)
            let primary = Store.state.isBtcSwapped ? fiatAmount.description : tokenAmount.description
            let secondary = Store.state.isBtcSwapped ? tokenAmount.description : fiatAmount.description
            let message = String(format: S.TransactionDetails.received, "\(primary) (\(secondary))")
            Store.trigger(name: .lightWeightAlert(message))
            showLocalNotification(message: message)
            ping()
        }
    }

    private func requestTxUpdate() {
        if updateTimer == nil {
            updateTimer = Timer.scheduledTimer(timeInterval: updateDebounceInterval, target: self, selector: #selector(updateTransactions), userInfo: nil, repeats: false)
        }
    }

    @objc private func updateTransactions() {
        updateTimer?.invalidate()
        updateTimer = nil
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let myself = self else { return }
            guard let txRefs = myself.wallet?.transactions else { return }
            let transactions = myself.makeTransactionViewModels(transactions: txRefs,
                                                              rate: myself.currency.state.currentRate)
            if transactions.count > 0 {
                DispatchQueue.main.async {
                    Store.perform(action: WalletChange(myself.currency).setTransactions(transactions))
                }
            }
        }
    }

    func makeTransactionViewModels(transactions: [BRTxRef?], rate: Rate?) -> [Transaction] {
        return transactions.flatMap{ $0 }.sorted {
            if $0.pointee.timestamp == 0 {
                return true
            } else if $1.pointee.timestamp == 0 {
                return false
            } else {
                return $0.pointee.timestamp > $1.pointee.timestamp
            }
            }.flatMap {
                return BtcTransaction($0, walletManager: self, kvStore: kvStore, rate: rate)
        }
    }

    private func ping() {
        guard let url = Bundle.main.url(forResource: "coinflip", withExtension: "aiff") else { return }
        var id: SystemSoundID = 0
        AudioServicesCreateSystemSoundID(url as CFURL , &id)
        AudioServicesAddSystemSoundCompletion(id, nil, nil, { soundId, _ in
            AudioServicesDisposeSystemSoundID(soundId)
        }, nil)
        AudioServicesPlaySystemSound(id)
    }

    private func showLocalNotification(message: String) {
        guard UIApplication.shared.applicationState == .background || UIApplication.shared.applicationState == .inactive else { return }
        guard Store.state.isPushNotificationsEnabled else { return }
        UIApplication.shared.applicationIconBadgeNumber = UIApplication.shared.applicationIconBadgeNumber + 1
        let notification = UILocalNotification()
        notification.alertBody = message
        notification.soundName = "coinflip.aiff"
        UIApplication.shared.presentLocalNotificationNow(notification)
    }
}
