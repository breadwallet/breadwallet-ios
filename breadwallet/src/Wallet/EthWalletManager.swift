//
//  EthWalletManager.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2018-04-04.
//  Copyright © 2018 breadwallet LLC. All rights reserved.
//

import Foundation
import BRCore

class EthWalletManager: WalletManager {
    
    // MARK: 

    private static let defaultGasPrice = etherCreateNumber(1, GWEI).valueInWEI
    private static let maxGasPrice = etherCreateNumber(100, GWEI).valueInWEI
    
    enum SendTransactionResult {
        case success(EthTransaction, ERC20Transaction?, String)
        case authenticationFailed
        case error(JSONRPCError)
    }
    
    // MARK: WalletManager

    let currency: Currency = Currencies.eth
    var kvStore: BRReplicatedKVStore?
    weak var apiClient: BRAPIClient? {
        didSet {
            if let apiClient = apiClient {
                assert(apiClient.authKey != nil)
                self.node.connect()
            } else {
                self.node.disconnect()
            }
        }
    }
    
    // MARK: Eth
    
    var address: String?
    var gasPrice: UInt256 = EthWalletManager.defaultGasPrice {
        didSet {
            if gasPrice > EthWalletManager.maxGasPrice {
                gasPrice = EthWalletManager.maxGasPrice
            }
            node.updateDefaultGasPrice(gasPrice)
        }
    }
    
    /// identifies a wallet by the ethereum public key
    var walletID: String?
    
    var tokens: [ERC20Token] = [] {
        didSet {
            tokens.forEach { token in
                if node.findWallet(forCurrency: token) == nil {
                    let wallet = node.wallet(token) // creates the core wallet
                    wallet.updateBalance() // trigger initial balance update to skip core refresh interval delay
                }
            }
        }
    }
    
    private var node: EthereumLightNode!
    private let syncState = RequestSyncState(timeout: 2) // 2s until sync indicator shown

    // MARK: -
    
    init?(publicKey: BRKey) {
        let network: EthereumNetwork = (E.isTestnet || E.isRunningTests) ? .testnet : .mainnet
        node = EthereumLightNode(client: self,
                                 listener: self,
                                 network: network,
                                 publicKey: publicKey)
        _ = node.wallet(Currencies.eth) // create eth wallet
        let address = node.address
        self.address = address
        DispatchQueue.main.async {
            Store.perform(action: WalletChange(self.currency).set(self.currency.state!.mutate(receiveAddress: address)))
        }
        if let walletID = getWalletID() {
            self.walletID = walletID
            print("walletID:", walletID)
        }
    }
    
    /// Sets the token definitions in Core Ethereum
    func setAvailableTokens(_ tokens: [ERC20Token]) {
        node.setTokens(tokens)
    }
    
    /// Fetches balances for all specified tokens and adds any that have a non-zero balance to the users's wallet.
    func discoverAndAddTokensWithBalance(in availableTokens: [ERC20Token], completion: @escaping () -> Void) {
        findTokensWithBalance(in: availableTokens) { tokensWithBalance in
            self.addTokenWallets(tokensWithBalance)
            completion()
        }
    }
    
    private func findTokensWithBalance(in tokens: [ERC20Token], completion: @escaping ([ERC20Token]) -> Void) {
        guard let apiClient = apiClient, let address = address else { return assertionFailure() }
        var tokensWithBalance = [ERC20Token]()
        let group = DispatchGroup()
        let queue = DispatchQueue.global(qos: .utility)
        queue.async {
            for token in tokens {
                group.enter()
                apiClient.getTokenBalance(address: address, token: token) { result in
                    if case .success(let value) = result {
                        let balance = UInt256(hexString: value)
                        if balance > UInt256(0) {
                            tokensWithBalance.append(token)
                        }
                    }
                    group.leave()
                }
            }
            group.notify(queue: queue) {
                completion(tokensWithBalance)
            }
        }
    }
    
    private func addTokenWallets(_ tokens: [ERC20Token]) {
        guard let kvStore = kvStore, let metaData = CurrencyListMetaData(kvStore: kvStore) else { return assertionFailure() }
        let hiddenTokenAddresses = metaData.hiddenTokenAddresses
        let tokensToBeAdded = tokens.filter {
            return Store.state.wallets[$0.code] == nil && !hiddenTokenAddresses.contains($0.code)
        }
        var displayOrder = Store.state.displayCurrencies.count
        let newWallets: [String: WalletState] = tokensToBeAdded.reduce([String: WalletState]()) { (dictionary, currency) -> [String: WalletState] in
            var dictionary = dictionary
            dictionary[currency.code] = WalletState.initial(currency, displayOrder: displayOrder)
            displayOrder += 1
            return dictionary
        }
        
        metaData.addTokenAddresses(addresses: tokensToBeAdded.map { $0.address })
        do {
            _ = try kvStore.set(metaData)
        } catch let error {
            print("error setting wallet info: \(error)")
        }
        DispatchQueue.main.async {
            Store.perform(action: ManageWallets.AddWallets(newWallets))
        }
    }
    
    func defaultGasLimit(currency: Currency) -> UInt64 {
        let wallet = node.wallet(currency)
        return wallet.defaultGasLimit
    }

    /// Creates an ETH transaction or ERC20 token transfer
    /// gasPrice and gasLimit parameters are only used for contract transactions
    func createTransaction(currency: Currency,
                           toAddress: String,
                           amount: UInt256,
                           abi: String? = nil,
                           gasPrice: UInt256? = nil,
                           gasLimit: UInt256) -> (EthereumTransaction, EthereumWallet) {
        let wallet = node.wallet(currency)
        let tx: EthereumTransaction
        if let abi = abi {
            tx = wallet.createContractTransaction(recvAddress: toAddress, amount: amount, data: abi, gasPrice: gasPrice, gasLimit: gasLimit.asUInt64)
        } else {
            tx = wallet.createTransaction(currency: currency, recvAddress: toAddress, amount: amount)
            lightNodeAnnounceGasEstimate(node.core, wallet.identifier, tx.identifier, gasLimit.hexString, 0)
        }

        return (tx, wallet)
    }
    
    /// Publishes a signed ETH transaction or ERC20 token transfer
    func sendTransaction(_ tx: EthereumTransaction,
                         callback: @escaping (SendTransactionResult) -> Void) {
        guard let accountAddress = address, let apiClient = apiClient else { return assertionFailure() }
        let currency = tx.currency
        let wallet = node.wallet(currency)
        let txRawHex = wallet.rawTransactionHexEncoded(tx)
        
        apiClient.sendRawTransaction(rawTx: txRawHex, handler: { [unowned self] result in
            switch result {
            case .success(let txHash):
                wallet.announceSubmitTransaction(tx, hash: txHash)
                assert(tx.hash == txHash)
                self.updateTransactions(currency)
                
                let pendingEthTx = EthTransaction(tx: tx,
                                                  accountAddress: accountAddress,
                                                  kvStore: self.kvStore,
                                                  rate: nil)
                
                if let token = currency as? ERC20Token {
                    let pendingTokenTx = ERC20Transaction(tx: tx,
                                                          accountAddress: accountAddress,
                                                          token: token,
                                                          kvStore: self.kvStore,
                                                          rate: nil)
                    callback(.success(pendingEthTx, pendingTokenTx, txRawHex))
                } else {
                    callback(.success(pendingEthTx, nil, txRawHex))
                }
            case .error(let error):
                callback(.error(error))
            }
        })
    }

    func isOwnAddress(_ address: String) -> Bool {
        return address.lowercased() == self.address?.lowercased()
    }
    
    func resetForWipe() {
        node.disconnect()
        tokens.removeAll()
    }
    
    // MARK: - Private
    
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
    
    /// Updates wallet state with transactions from core
    private func updateTransactions(_ currency: Currency) {
        guard let accountAddress = address else { return assertionFailure() }
        let txs = self.node.wallet(currency).transactions
        var viewModels: [Transaction]
        
        if let token = currency as? ERC20Token {
            viewModels = txs.map { ERC20Transaction(tx: $0, accountAddress: accountAddress, token: token, kvStore: self.kvStore, rate: currency.state?.currentRate) }
        } else {
            viewModels = txs.map { EthTransaction(tx: $0, accountAddress: accountAddress, kvStore: self.kvStore, rate: currency.state?.currentRate) }
        }
        viewModels.sort(by: { $0.timestamp > $1.timestamp })
        //print("processed \(txs.count) \(currency.code) transactions")
        Store.perform(action: WalletChange(currency).setTransactions(viewModels))
    }
}

/// The EthereumClient functions are called by Core to send requests to the network
extension EthWalletManager: EthereumClient {
    func getGasPrice(wallet: EthereumWallet, completion: @escaping (String) -> Void) {
        // unused - gas price is set by the FeeUpdater
        assertionFailure()
    }
    
    func getGasEstimate(wallet: EthereumWallet, tid: EthereumTransactionId, to: String, amount: String, data: String, completion: @escaping (String) -> Void) {
        // unused - gas limit estimate is triggerd by the Sender (GasEstimator)
    }
    
    func getBalance(wallet: EthereumWallet, address: String, completion: @escaping (String) -> Void) {
        guard let apiClient = apiClient else { return assertionFailure() }
        let currency = wallet.currency
        
        if let token = currency as? ERC20Token {
            guard tokens.contains(token) else { return }
            guard syncState.willBeginRequest(.getBalance, currencies: [currency]) else { return print("getBalance \(currency.code) skipped") }
            apiClient.getTokenBalance(address: address, token: token) { result in
                switch result {
                case .success(let value):
                    completion(value)
                    self.syncState.didEndRequest(.getBalance, currencies: [currency], success: true)
                case .error(let error):
                    print("getBalance error: \(error.localizedDescription)")
                    self.syncState.didEndRequest(.getBalance, currencies: [currency], success: false)
                }
            }
        } else {
            guard syncState.willBeginRequest(.getBalance, currencies: [currency]) else { return print("getBalance \(currency.code) skipped") }
            apiClient.getBalance(address: address) { result in
                switch result {
                case .success(let value):
                    completion(value)
                    self.syncState.didEndRequest(.getBalance, currencies: [currency], success: true)
                case .error(let error):
                    print("getBalance error: \(error.localizedDescription)")
                    self.syncState.didEndRequest(.getBalance, currencies: [currency], success: false)
                }
            }
        }
    }
    
    func submitTransaction(wallet: EthereumWallet, tid: EthereumTransactionId, rawTransaction: String, completion: @escaping (String) -> Void) {
        // unused - transactions are submitted in the send function
        assertionFailure()
    }
    
    func getTransactions(address: String, completion: @escaping ([EthTxJSON]) -> Void) {
        guard let apiClient = apiClient else { return assertionFailure() }
        guard syncState.willBeginRequest(.getTransactions, currencies: [currency]) else { return print("getTransactions skipped") }
        
        apiClient.getEthTxList(address: address) { [weak self] result in
            guard let `self` = self else { return }
            switch result {
            case .success(let jsonObjects):
                completion(jsonObjects) // imports transaction json data into core
                self.updateTransactions(self.currency)
                self.syncState.didEndRequest(.getTransactions, currencies: [self.currency], success: true)
            case .error(let error):
                print("getTransactions error: \(error.localizedDescription)")
                self.syncState.didEndRequest(.getTransactions, currencies: [self.currency], success: false)
            }
        }
    }
    
    func getLogs(address: String, contract: String?, event: String, completion: @escaping ([EthLogEventJSON]) -> Void) {
        guard let apiClient = apiClient else { return assertionFailure() }
        var tokens = [ERC20Token]()
        if let contract = contract, let token = self.tokens.filter({ $0.address == contract }).first {
            tokens = [token]
        } else {
            tokens = self.tokens
        }
        guard syncState.willBeginRequest(.getTransactions, currencies: tokens) else { return print("getLogs skipped") }
        
        apiClient.getTokenTransferLogs(address: address, contractAddress: contract) { [weak self] result in
            guard let `self` = self else { return }
            switch result {
            case .success(let jsonObjects):
                completion(jsonObjects) // imports logs json data into core
                for token in self.tokens {
                    self.updateTransactions(token)
                }
                self.syncState.didEndRequest(.getTransactions, currencies: tokens, success: true)
            case .error(let error):
                print("getLogs error: \(error.localizedDescription)")
                self.syncState.didEndRequest(.getTransactions, currencies: tokens, success: false)
            }
        }
    }
    
    func getBlockNumber(completion: @escaping EthereumClient.AmountHandler) {
        guard let apiClient = apiClient else { return assertionFailure() }
        apiClient.getLastBlockNumber { result in
            switch result {
            case .success(let blockNumber):
                completion(blockNumber)
            case .error(let error):
                print("getLatestBlock error: \(error.localizedDescription)")
            }
        }
    }
    
    func getNonce(address: String, completion: @escaping EthereumClient.AmountHandler) {
        guard let apiClient = apiClient else { return assertionFailure() }
        apiClient.getTransactionCount(address: address) { result in
            switch result {
            case .success(let nonce):
                completion(nonce)
            case .error(let error):
                print("getNonce error: \(error.localizedDescription)")
            }
        }
    }
}

/// The EthereumListener functions are called by Core to notify of events
extension EthWalletManager: EthereumListener {
    
    func handleWalletEvent(wallet: EthereumWallet,
                           event: EthereumWalletEvent,
                           status: BREthereumStatus,
                           errorDesc: String?) {
        //print("\(wallet.currency.code) wallet event: \(event), status: \(status.rawValue)\(errorDesc != nil ? ", error: \(errorDesc!)" : "")")
        switch event {
        case .balanceUpdated:
            DispatchQueue.main.async {
                Store.perform(action: WalletChange(wallet.currency).setBalance(wallet.balance))
            }
        default:
            break
        }
    }
    
    func handleTransactionEvent(wallet: EthereumWallet,
                                transaction: EthereumTransaction,
                                event: EthereumTransactionEvent,
                                status: BREthereumStatus,
                                errorDesc: String?) {
        //print("\(wallet.currency.code) tx event: \(event), status: \(status), \(errorDesc != nil ? "error: \(errorDesc!)" : "hash: \(transaction.hash)")")
    }
    
    func handleBlockEvent(block: EthereumBlock,
                          event: BREthereumBlockEvent,
                          status: BREthereumStatus,
                          errorDesc: String?) {
        // unused
    }
}

extension EthWalletManager {
    /// Manages currency sync indicators based on request state
    class RequestSyncState {
        
        enum Request {
            case getBalance
            case getTransactions
        }
        
        init(timeout: TimeInterval) {
            timeoutInterval = timeout
            
            inProgress[.getBalance] = []
            inProgress[.getTransactions] = []
        }
        
        func stop() {
            timeoutTimer?.invalidate()
        }
        
        /// Call before initiating a fetch. Returns false if a fetch of this type is already in progress, true otherwise.
        func willBeginRequest(_ request: Request, currencies: [Currency]) -> Bool {
            guard let currenciesInProgress = inProgress[request] else {
                assertionFailure()
                return false
            }
            
            guard Set(currenciesInProgress.map({ $0.code })).isDisjoint(with: currencies.map({ $0.code })) else {
                return false
            }
            
            inProgress[request] = currenciesInProgress + currencies
            
            for currency in currencies where currency.state?.syncState == .connecting {
                DispatchQueue.main.async {
                    Store.perform(action: WalletChange(currency).setProgress(progress: 0.8, timestamp: 0))
                    Store.perform(action: WalletChange(currency).setSyncingState(.syncing))
                }
            }
            
            if firstTime && timeoutTimer == nil {
                timeoutTimer = Timer.scheduledTimer(timeInterval: timeoutInterval,
                                                    target: self,
                                                    selector: #selector(timeout),
                                                    userInfo: nil,
                                                    repeats: false)
            }
            return true
        }
        
        /// Call after a fetch has completed
        func didEndRequest(_ request: Request, currencies: [Currency], success: Bool) {
            guard let currenciesInProgress = inProgress[request] else { return assertionFailure() }
            
            let finishedCodes = currencies.map { $0.code }
            inProgress[request] = currenciesInProgress.filter({ !finishedCodes.contains($0.code) })
            currencies.forEach { currency in
                DispatchQueue.main.async {
                    Store.perform(action: WalletChange(currency).setProgress(progress: success ? 1.0 : 0.0, timestamp: 0))
                    Store.perform(action: WalletChange(currency).setSyncingState(success ? .success : .connecting))
                }
            }
            
            if allFinished {
                firstTime = false
                timeoutTimer?.invalidate()
                timeoutTimer = nil
            }
        }
        
        // MARK: Private
        
        private var firstTime: Bool = true
        private var timeoutTimer: Timer?
        private var timeoutInterval: TimeInterval
        private var inProgress: [Request: [Currency]] = [:]
        private var allFinished: Bool {
            return inProgress.values.filter({ !$0.isEmpty }).isEmpty
        }
        
        @objc private func timeout() {
            // only show sync indicator for the first fetch
            guard firstTime else { return }
            
            for currency in inProgress.values.flatMap({ $0 }) {
                DispatchQueue.main.async {
                    Store.perform(action: WalletChange(currency).setProgress(progress: 0.8, timestamp: 0))
                    Store.perform(action: WalletChange(currency).setSyncingState(.syncing))
                }
            }
        }
    }
}
