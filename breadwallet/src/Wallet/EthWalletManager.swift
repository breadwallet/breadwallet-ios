//
//  EthWalletManager.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2018-04-04.
//  Copyright © 2018 breadwallet LLC. All rights reserved.
//

import Foundation
import BRCore
import BRCore.Ethereum

class EthWalletManager : WalletManager {
    static let defaultGasLimit: UInt64 = 48_000 // higher than standard 21000 to allow sending to contracts
    static let defaultTokenTransferGasLimit: UInt64 = 150_000
    static let defaultGasPrice = etherCreateNumber(1, GWEI).valueInWEI
    static let maxGasPrice = etherCreateNumber(100, GWEI).valueInWEI

    var peerManager: BRPeerManager?
    var wallet: BRWallet?
    var currency: CurrencyDef = Currencies.eth
    var kvStore: BRReplicatedKVStore?
    var apiClient: BRAPIClient? {
        didSet {
            DispatchQueue.main.async {
                self.balanceRefresher.start()
            }
        }
    }
    var address: String?
    var gasPrice: UInt256 = EthWalletManager.defaultGasPrice {
        didSet {
            if gasPrice > EthWalletManager.maxGasPrice {
                gasPrice = EthWalletManager.maxGasPrice
            }
        }
    }
    var walletID: String?
    var tokens: [ERC20Token] = [] {
        didSet {
            balanceRefresher.trigger()
            refreshTransactions()
        }
    }
    var ethAddress: BREthereumAddress?
    var account: BREthereumAccount?
    var ethWallet: BREthereumWallet?
    var latestBlockNumber: UInt64?
    
    private var pendingTransactions = [EthTx]()
    private var pendingTokenTransactions = [String: [ERC20Transaction]]()
    
    private let balanceUpdateInterval: TimeInterval = 10
    private let txUpdateInterval: TimeInterval = 10
    private let slowSyncTimeoutInterval: TimeInterval = 2
    
    private var balanceRefresher: Refresher!
    private var txRefresher: Refresher!
    private var txRefreshCurrency: CurrencyDef?

    // MARK: -
    
    init?() {
        guard let pubKey = ethPubKey else { return nil }
        self.account = createAccountWithPublicKey(pubKey)
        guard account != nil else { return nil }
        self.ethAddress = accountGetPrimaryAddress(self.account)
        self.ethWallet = walletCreate(account, E.isTestnet ? ethereumTestnet : ethereumMainnet)
        if let address = addressAsString(self.ethAddress) {
            if let address = String(cString: address, encoding: .utf8) {
                self.address = address
                Store.perform(action: WalletChange(self.currency).set(self.currency.state!.mutate(receiveAddress: address)))
            }
        }
        if let walletID = getWalletID() {
            self.walletID = walletID
            print("walletID:", walletID)
        }
        
        balanceRefresher = Refresher(interval: balanceUpdateInterval,
                                     timeout: slowSyncTimeoutInterval,
                                     refreshHandler: refreshBalances)
        txRefresher = Refresher(interval: txUpdateInterval,
                                timeout: slowSyncTimeoutInterval,
                                refreshHandler: refreshTransactions)
    }

    func beginFetchingTransactions(currency: CurrencyDef) {
        txRefreshCurrency = currency
        txRefresher.start()
    }
    
    func stopFetchingTransactions() {
        txRefresher.stop()
        txRefreshCurrency = nil
    }

    private func refreshBalances() {
        updateBalance()
        updateTokenBalances()
    }
    
    private func updateBalance() {
        guard let address = address, balanceRefresher.willBeginRefresh(self.currency) else { return }
        apiClient?.getBalance(address: address, handler: { [weak self] result in
            guard let `self` = self else { return }
            self.balanceRefresher.didEndRefresh(self.currency)
            switch result {
            case .success(let value):
                Store.perform(action: WalletChange(self.currency).setSyncingState(.success))
                Store.perform(action: WalletChange(self.currency).setBalance(value))
            case .error(let error):
                print("getBalance error: \(error.localizedDescription)")
            }
        })
    }
    
    private func refreshTransactions() {
        guard txRefreshCurrency != nil else {
            // fetch all
            updateTransactionList()
            tokens.forEach { updateTokenTransactions(token: $0) }
            return
        }
        
        if let token = txRefreshCurrency as? ERC20Token {
            updateTokenTransactions(token: token)
        } else {
            updateTransactionList()
        }
        updateBlockNumber()
    }
    
    private func updateTransactionList() {
        guard let address = address,
            let apiClient = apiClient,
            txRefresher.willBeginRefresh(currency) else { return }
        apiClient.getEthTxList(address: address, handler: { [weak self] result in
            guard let `self` = self else { return }
            self.txRefresher.didEndRefresh(self.currency)
            guard case .success(let txList) = result else { return }
            for tx in txList {
                if let index = self.pendingTransactions.index(where: { $0.hash == tx.hash }) {
                    self.pendingTransactions.remove(at: index)
                }
            }
            let transactions = (self.pendingTransactions + txList).map { EthTransaction(tx: $0, accountAddress: address, kvStore: self.kvStore, rate: self.currency.state?.currentRate) }
            Store.perform(action: WalletChange(self.currency).setTransactions(transactions))
        })
    }
    
    private func updateBlockNumber() {
        apiClient?.getLastBlockNumber() { [weak self] result in
            switch result {
            case .success(let blockNumber):
                self?.latestBlockNumber = blockNumber.asUInt64
            case .error(let error):
                print("getLatestBlock error: \(error.localizedDescription)")
            }
        }
    }

    func sendTx(toAddress: String, amount: UInt256, callback: @escaping (JSONRPCResult<EthTx>)->Void) {
        guard var privKey = BRKey(privKey: ethPrivKey!) else { return }
        privKey.compressed = 0
        defer { privKey.clean() }
        let ethToAddress = createAddress(toAddress)
        let ethAmount = amountCreateEther((etherCreate(amount)))
        let gasPrice = gasPriceCreate((etherCreate(self.gasPrice)))
        let gasLimit = gasCreate(EthWalletManager.defaultGasLimit)
        let nonce = getNonce()
        let tx = walletCreateTransactionDetailed(ethWallet, ethToAddress, ethAmount, gasPrice, gasLimit, nonce)
        walletSignTransactionWithPrivateKey(ethWallet, tx, privKey)
        let txString = walletGetRawTransactionHexEncoded(ethWallet, tx, "0x")
        let swiftTxString = String(cString: UnsafeRawPointer(txString!).assumingMemoryBound(to: CChar.self))
        apiClient?.sendRawTransaction(rawTx: String(cString: txString!, encoding: .utf8)!, handler: { [unowned self] result in
            switch result {
            case .success(let txHash):
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
                                      isError: false,
                                      rawTx: swiftTxString) // TODO:ERC20 cleanup
                self.pendingTransactions.append(pendingTx)
                self.balanceRefresher.trigger()
                self.txRefresher.trigger()
                callback(.success(pendingTx))
            case .error(let error):
                callback(.error(error))
            }
        })
    }

    //Nonce is either previous nonce + 1 , or 1 if no transactions have been sent yet
    private func getNonce() -> UInt64 {
        let sentTransactions = Store.state.wallets[Currencies.eth.code]?.transactions.filter { self.isOwnAddress(($0 as! EthTransaction).fromAddress) }
        let previousNonce = sentTransactions?.map { ($0 as! EthTransaction).nonce }.max()
        return (previousNonce == nil) ? 0 : previousNonce! + 1
    }

    func canUseBiometrics(forTx: BRTxRef) -> Bool {
        return false
    }

    func isOwnAddress(_ address: String) -> Bool {
        return address.lowercased() == self.address?.lowercased()
    }

    // walletID identifies a wallet by the ethereum public key
    // 1. compute the sha256(address[0]) -- note address excludes the "0x" prefix
    // 2. take the first 10 bytes of the sha256 and base32 encode it (lowercasing the result)
    // 3. split the result into chunks of 4-character strings and join with a space
    //
    // this provides an easily human-readable (and verbally-recitable) string that can
    // be used to uniquely identify this wallet.
    //
    // the user may then provide this ID for later lookup in associated systems
    private func getWalletID() -> String? {
        if let small = address?.dropFirst(2).data(using: .utf8)?.sha256[0..<10].base32.lowercased() {
            return stride(from: 0, to: small.count, by: 4).map {
                let start = small.index(small.startIndex, offsetBy: $0)
                let end = small.index(start, offsetBy: 4, limitedBy: small.endIndex) ?? small.endIndex
                return String(small[start..<end])
                }.joined(separator: " ")
        }
        return nil
    }
    
    func resetForWipe() {
        txRefresher.stop()
        balanceRefresher.stop()
        tokens.removeAll()
    }
}

// MARK: - ERC20

extension EthWalletManager {
    enum SendTokenResult {
        case success((EthTransaction, ERC20Transaction))
        case error(JSONRPCError)
    }
    
    func send(token: ERC20Token, toAddress: String, amount: UInt256, callback: @escaping (SendTokenResult)->Void) {
        guard var privKey = BRKey(privKey: ethPrivKey!) else { return }
        privKey.compressed = 0
        defer { privKey.clean() }
        
        guard let ethToken = tokenLookup(token.address) else {
            return assertionFailure("token \(token.code) not found in core!")
        }
        let tokenWallet = walletCreateHoldingToken(account, E.isTestnet ? ethereumTestnet : ethereumMainnet, ethToken)
        let ethToAddress = createAddress(toAddress)
        let tokenAmount = amountCreateToken((createTokenQuantity(ethToken, amount)))
        let gasPrice = gasPriceCreate((etherCreate(self.gasPrice)))
        let gasLimit = gasCreate(EthWalletManager.defaultTokenTransferGasLimit)
        let nonce = getNonce()
        let tx = walletCreateTransactionDetailed(tokenWallet, ethToAddress, tokenAmount, gasPrice, gasLimit, nonce)
        walletSignTransactionWithPrivateKey(tokenWallet, tx, privKey)
        let txString = walletGetRawTransactionHexEncoded(tokenWallet, tx, "0x")
        let swiftTxString = String(cString: UnsafeRawPointer(txString!).assumingMemoryBound(to: CChar.self))
        apiClient?.sendRawTransaction(rawTx: String(cString: txString!, encoding: .utf8)!, handler: { [unowned self] result in
            switch result {
            case .success(let txHash):
                let ethTx = EthTx(blockNumber: 0,
                                      timeStamp: Date().timeIntervalSince1970,
                                      value: 0,
                                      gasPrice: gasPrice.etherPerGas.valueInWEI,
                                      gasLimit: gasLimit.amountOfGas,
                                      gasUsed: 0,
                                      from: self.address!,
                                      to: token.address,
                                      confirmations: 0,
                                      nonce: UInt64(nonce),
                                      hash: txHash,
                                      isError: false,
                                      rawTx: swiftTxString) // TODO:ERC20 cleanup
                let pendingEthTx = EthTransaction(tx: ethTx,
                                                  accountAddress: self.address!,
                                                  kvStore: self.kvStore,
                                                  rate: self.currency.state?.currentRate)
                let pendingTokenTx = ERC20Transaction(token: token,
                                                      accountAddress: self.address!,
                                                      toAddress: toAddress,
                                                      amount: amount,
                                                      timestamp: Date().timeIntervalSince1970,
                                                      gasPrice: gasPrice.etherPerGas.valueInWEI,
                                                      hash: txHash,
                                                      kvStore: self.kvStore)
                self.pendingTransactions.append(ethTx)
                self.addPendingTokenTransaction(pendingTokenTx)
                self.balanceRefresher.trigger()
                self.txRefresher.trigger()
                callback(.success((pendingEthTx, pendingTokenTx)))
                
            case .error(let error):
                callback(.error(error))
            }
        })
    }
    
    private func updateTokenBalances() {
        guard let address = address, let apiClient = apiClient else { return }
        tokens.forEach { token in
            if balanceRefresher.willBeginRefresh(token) {
                apiClient.getTokenBalance(address: address, token: token, handler: { [weak self] result in
                    guard let `self` = self else { return }
                    self.balanceRefresher.didEndRefresh(token)
                    switch result {
                    case .success(let value):
                        Store.perform(action: WalletChange(token).setBalance(value))
                    case .error(let error):
                        print("getTokenBalance error: \(error.localizedDescription)")
                    }
                })
            }
        }
    }
    
    private func updateTokenTransactions(token: ERC20Token) {
        guard let address = address,
            let apiClient = apiClient,
            txRefresher.willBeginRefresh(token) else { return }
        apiClient.getTokenTransactions(address: address, token: token, handler: { [weak self] result in
            guard let `self` = self else { return }
            self.txRefresher.didEndRefresh(token)
            guard case .success(let eventList) = result else { return }
            var pendingTokenTxs: [ERC20Transaction] = self.pendingTokenTransactions[token.code] ?? []
            if pendingTokenTxs.count > 0 {
                for event in eventList {
                    if let index = pendingTokenTxs.index(where: { $0.hash == event.transactionHash }) {
                        pendingTokenTxs.remove(at: index)
                    }
                }
            }
            let transactions = pendingTokenTxs + eventList.sorted(by: { $0.timeStamp > $1.timeStamp }).map { ERC20Transaction(event: $0, accountAddress: address, token: token, latestBlockNumber: self.latestBlockNumber, kvStore: self.kvStore, rate: token.state?.currentRate) }
            Store.perform(action: WalletChange(token).setTransactions(transactions))
        })
    }
    
    private func addPendingTokenTransaction(_ tx: ERC20Transaction) {
        if pendingTokenTransactions[tx.currency.code] == nil {
            pendingTokenTransactions[tx.currency.code] = [ERC20Transaction]()
        }
        pendingTokenTransactions[tx.currency.code]?.append(tx)
    }
}

extension EthWalletManager {
    /// Handles refreshing currency state and showing/hiding sync indicators
    class Refresher {
        
        /// Triggers _refreshHandler_ after every _refreshInterval_, shows syncIndicator after _timeoutInterval_
        init(interval: TimeInterval, timeout: TimeInterval, refreshHandler: @escaping (() -> Void)) {
            self.refreshInterval = interval
            self.timeoutInterval = timeout
            self.refreshHandler = refreshHandler
        }
        
        /// Initiates a refresh immediately and starts the timer for intermittent refresh
        func start() {
            firstTime = true
            refreshTimer = Timer.scheduledTimer(timeInterval: refreshInterval,
                                                target: self,
                                                selector: #selector(refresh),
                                                userInfo: nil,
                                                repeats: true)
            refresh()
        }
        
        /// Stop intermittent refresh
        func stop() {
            refreshTimer?.invalidate()
            timeoutTimer?.invalidate()
        }
        
        /// Manually trigger a refresh. Does not reset the refresh interval.
        func trigger() {
            refreshTimer?.fire()
        }
        
        /// Call before initiating a fetch. Returns false is a fetch is already in progress, true otherwise.
        func willBeginRefresh(_ currency: CurrencyDef) -> Bool {
            if currency.state?.syncState == .connecting {
                Store.perform(action: WalletChange(currency).setProgress(progress: 0.8, timestamp: 0))
                Store.perform(action: WalletChange(currency).setSyncingState(.syncing))
            }
            guard !inProgress.contains(where: { $0.code == currency.code }) else { return false }
            inProgress.append(currency)
            return true
        }
        
        /// Call after a fetch has completed
        func didEndRefresh(_ currency: CurrencyDef) {
            Store.perform(action: WalletChange(currency).setSyncingState(.success))
            inProgress = inProgress.filter { $0.code != currency.code }
            if inProgress.isEmpty {
                firstTime = false
                timeoutTimer?.invalidate()
                timeoutTimer = nil
            }
        }
        
        // MARK: Private
        
        private var firstTime: Bool = true
        private var refreshTimer: Timer?
        private var timeoutTimer: Timer?
        private var refreshHandler: (() -> Void)
        private var refreshInterval: TimeInterval
        private var timeoutInterval: TimeInterval
        private var inProgress: [CurrencyDef] = []
        
        @objc private func refresh() {
            if firstTime && timeoutTimer == nil {
                timeoutTimer = Timer.scheduledTimer(timeInterval: timeoutInterval,
                                                    target: self,
                                                    selector: #selector(timeout),
                                                    userInfo: nil,
                                                    repeats: false)
            }
            refreshHandler()
        }
        
        @objc private func timeout() {
            // only show sync indicator for the first fetch
            guard firstTime else { return }
            for currency in inProgress {
                Store.perform(action: WalletChange(currency).setProgress(progress: 0.8, timestamp: 0))
                Store.perform(action: WalletChange(currency).setSyncingState(.syncing))
            }
        }
    }
}
