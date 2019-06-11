//
//  EthWalletManager.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2018-04-04.
//  Copyright © 2018 breadwallet LLC. All rights reserved.
//

import Foundation
import BRCore

// swiftlint:disable function_parameter_count

class EthWalletManager: WalletManager {

    // MARK: Constants

    private static let defaultGasPrice = etherCreateNumber(1, GWEI).valueInWEI
    private static let maxGasPrice = etherCreateNumber(100, GWEI).valueInWEI
    private let transactionUpdateInterval = 5.0 // seconds between transaction list UI updates
    private let transactionSendTimeout = 10.0

    // MARK: Types

    enum SendError: Error {
        case invalidWalletState
        case publishError(EthereumTransferError)
        case timedOut
    }

    typealias GasEstimationResult = Result<Void, SendError>
    typealias SendTransactionResult = Result<(tx: EthTransaction, tokenTx: ERC20Transaction?, rawTx: String), SendError>

    private struct GasEstimateRequest {
        let tx: EthereumTransfer
        /// Estimated gas limit, skip gas esimtation request if set
        var gasEstimate: UInt256?
        let completion: (GasEstimationResult) -> Void
    }

    private struct OutgoingTransaction {
        let tx: EthereumTransfer
        let completion: (SendTransactionResult) -> Void
        /// for token transfers this references the associated ETH transaction
        var associatedTx: EthereumTransfer?
        var tokenTransferSubmitted: Bool
        var txRawHex: String?

        init(tx: EthereumTransfer, completion: @escaping ((SendTransactionResult) -> Void)) {
            self.tx = tx
            self.completion = completion
            self.associatedTx = nil
            self.tokenTransferSubmitted = false
            self.txRawHex = nil
        }
    }
    
    // MARK: WalletManager

    let currency: Currency = Currencies.eth
    var kvStore: BRReplicatedKVStore?
    var apiClient: BRAPIClient {
        assert(Backend.isConnected)
        return Backend.apiClient
    }
    var isConnected: Bool {
        return node.isConnected
    }
    
    // MARK: Eth

    /// account address
    var address: String?

    /// default gas price for sending
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

    /// tokens with active wallets
    var tokens: [ERC20Token] = [] {
        didSet {
            print("[EWM] user token list updated: \(tokens.map { $0.code })")
            tokens.forEach { token in
                if token.core != nil, node.wallet(for: token) == nil {
                    createWallet(token)
                }
            }
        }
    }
    
    private var node: EthereumWalletManager!
    private var syncState = [String: WalletSyncState]()
    private var txUpdateTimer: Timer?
    private var pendingGasEstimate: GasEstimateRequest?
    private var pendingSend: OutgoingTransaction?
    private var sendTimeoutTimer: Timer? {
        willSet {
            sendTimeoutTimer?.invalidate()
        }
    }

    //
    // MARK: -
    //

    init?(publicKey: BRKey) {
        let network: EthereumNetwork = (E.isTestnet || E.isRunningTests) ? .testnet : .mainnet
        let mode = EthereumMode.brd_with_p2p_send
        node = EthereumWalletManager(client: self,
                                     network: network,
                                     mode: mode,
                                     key: .publicKey(publicKey),
                                     timestamp: 0,
                                     storagePath: C.coreDataDirURL.path)
        createWallet(Currencies.eth)
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

    deinit {
        disconnect()
    }

    // MARK: WalletManager

    func connect() {
        node.connect()

        if !UserDefaults.hasScannedForTokenBalances {
            discoverAndAddTokensWithBalance(in: Store.state.availableTokens) {
                UserDefaults.hasScannedForTokenBalances = true
            }
        }

        startUpdatingTransactions()
    }

    func disconnect() {
        stopUpdatingTransactions()
        node.disconnect()
    }

    func rescan() {
        print("[EWM] rescanning...")
        node.rescan()
    }

    func resetForWipe() {
        disconnect()
        // TODO: delete eth data dir
        tokens.removeAll()
    }

    func isOwnAddress(_ address: String) -> Bool {
        return address.lowercased() == self.address?.lowercased()
    }

    // MARK: - Eth

    func defaultGasLimit(currency: Currency) -> UInt64 {
        guard let wallet = node.wallet(for: currency) else { assertionFailure(); return 0 }
        return wallet.defaultGasLimit
    }

    /// Creates an ETH transaction or ERC20 token transfer
    /// gasPrice and gasLimit parameters are only used for contract transactions
    func createTransaction(currency: Currency,
                           toAddress: String,
                           amount: UInt256,
                           abi: String? = nil,
                           gasPrice: UInt256? = nil,
                           gasLimit: UInt256? = nil) -> (EthereumTransfer, EthereumWallet)? {
        guard let wallet = node.wallet(for: currency) else { assertionFailure(); return nil }
        let tx: EthereumTransfer
        if let abi = abi {
            tx = wallet.createContractTransaction(recvAddress: toAddress, amount: amount, data: abi, gasPrice: gasPrice, gasLimit: gasLimit?.asUInt64)
        } else {
            tx = wallet.createTransaction(currency: currency, recvAddress: toAddress, amount: amount)
        }

        return (tx, wallet)
    }

    /// Requets a gas estimate for the tx if no gasLimit is specified or sets the specified gasLimit
    func estimateGas(for tx: EthereumTransfer, gasLimit: UInt256? = nil, completion: @escaping (GasEstimationResult) -> Void) {
        guard let wallet = node.wallet(for: tx.currency) else {
            assertionFailure()
            return completion(.failure(.invalidWalletState))
        }
        waitForGasEstimation(for: tx, gasEstimate: gasLimit, completion: completion)
        // completion is called on gasEstimateUpdated event in handleTransferEvent
        wallet.updateGasEstimate(for: tx)
    }

    /// Publishes a signed ETH transaction or ERC20 token transfer
    func sendTransaction(_ tx: EthereumTransfer,
                         completion: @escaping (SendTransactionResult) -> Void) {
        let currency = tx.currency
        guard let wallet = node.wallet(for: currency) else { return assertionFailure() }
        waitForSend(tx, completion: completion)
        // completion is called after submitted or errored event in handleTransferEvent
        wallet.submit(transaction: tx)
    }

    // MARK: Private

    private func createWallet(_ currency: Currency) {
        node.createWallet(for: currency)
        syncState[currency.code] = WalletSyncState(currency: currency)
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

    // MARK: - Tokens

    public func updateTokenList(completion: (() -> Void)? = nil) {
        let processTokens: ([ERC20Token]) -> Void = { tokens in
            assert(!Thread.isMainThread)
            var tokens = tokens.sorted(by: { $0.code.compare($1.code, options: .caseInsensitive) == .orderedAscending })
            if E.isDebug {
                tokens.append(Currencies.tst)
            }
            self.node.setAvailableTokens(tokens)
            DispatchQueue.main.async {
                Store.perform(action: ManageWallets.SetAvailableTokens(tokens))
                print("[TokenList] tokens updated: \(tokens.count) tokens")
                completion?()
            }
        }

        let fm = FileManager.default
        guard let documentsDir = try? fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false) else { return assertionFailure() }
        let cachedFilePath = documentsDir.appendingPathComponent("tokens.json").path

        if let embeddedFilePath = Bundle.main.path(forResource: "tokens", ofType: "json"), !fm.fileExists(atPath: cachedFilePath) {
            do {
                try fm.copyItem(atPath: embeddedFilePath, toPath: cachedFilePath)
                print("[TokenList] copied bundle tokens list to cache")
            } catch let e {
                print("[TokenList] unable to copy bundled \(embeddedFilePath) -> \(cachedFilePath): \(e)")
            }
        }
        // fetch from network and update cached copy on success or return the cached copy if fetch fails
        Backend.apiClient.getTokenList { result in
            DispatchQueue.global(qos: .utility).async {
                switch result {
                case .success(let tokens):
                    // update cache
                    do {
                        let data = try JSONEncoder().encode(tokens)
                        try data.write(to: URL(fileURLWithPath: cachedFilePath))
                    } catch let e {
                        print("[TokenList] failed to write to cache: \(e.localizedDescription)")
                    }
                    processTokens(tokens)

                case .error(let error):
                    print("[TokenList] error fetching tokens: \(error)")
                    var tokens = [ERC20Token]()
                    do {
                        print("[TokenList] using cached token list")
                        let cachedData = try Data(contentsOf: URL(fileURLWithPath: cachedFilePath))
                        tokens = try JSONDecoder().decode([ERC20Token].self, from: cachedData)
                    } catch let e {
                        print("[TokenList] error reading from cache: \(e)")
                        fatalError("unable to read token list!")
                    }
                    processTokens(tokens)
                }
            }
        }
    }

    /// Fetches balances for all specified tokens and adds any that have a non-zero balance to the users's wallet.
    private func discoverAndAddTokensWithBalance(in availableTokens: [ERC20Token], completion: @escaping () -> Void) {
        findTokensWithBalance(in: availableTokens) { tokensWithBalance in
            self.addTokenWallets(tokensWithBalance)
            completion()
        }
    }

    private func findTokensWithBalance(in tokens: [ERC20Token], completion: @escaping ([ERC20Token]) -> Void) {
        guard let address = address else { return assertionFailure() }
        let apiClient = self.apiClient
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

    /// Adds wallets for the specified tokens to the user's stored wallet list and global wallet state
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
            print("[EWM] error setting wallet info: \(error)")
        }
        DispatchQueue.main.async {
            Store.perform(action: ManageWallets.AddWallets(newWallets))
        }
    }

    // MARK: - Transaction History

    /**
     Starts a timer to periodically fetch transactions from core and update the wallet state / UI

     This is done instead of reacting to each individual transaction event because updating
     the the wallet state triggers UI updates which could be expensive.
     */
    private func startUpdatingTransactions() {
        assert(txUpdateTimer == nil || txUpdateTimer!.isValid == false)
        DispatchQueue.main.async {
            self.txUpdateTimer = Timer.scheduledTimer(withTimeInterval: self.transactionUpdateInterval, repeats: true) { [unowned self] _ in
                self.updateTransactions()
            }
        }
    }

    private func stopUpdatingTransactions() {
        txUpdateTimer?.invalidate()
    }

    private func updateTransactions() {
        updateTransactions(currency: currency)
        tokens.forEach { self.updateTransactions(currency: $0) }
    }
    
    /// Updates wallet state with transactions from core
    private func updateTransactions(currency: Currency) {
        guard let accountAddress = address else { return assertionFailure() }
        guard self.node.wallet(for: currency) != nil else { return }  // wallet not created yet
        
        node.serialAsync {
            guard let txs = self.node.wallet(for: currency)?.transactions else { return assertionFailure("missing wallet") }

                var viewModels: [Transaction]
                if let token = currency as? ERC20Token {
                    viewModels = txs.map { ERC20Transaction(tx: $0,
                                                            accountAddress: accountAddress,
                                                            token: token,
                                                            kvStore: self.kvStore,
                                                            rate: currency.state?.currentRate) }
                } else {
                    viewModels = txs.map { EthTransaction(tx: $0,
                                                          accountAddress: accountAddress,
                                                          kvStore: self.kvStore,
                                                          rate: currency.state?.currentRate) }
                }
                viewModels.sort(by: { $0.timestamp > $1.timestamp })

                DispatchQueue.main.async {
                    Store.perform(action: WalletChange(currency).setTransactions(viewModels))
                }
        }
    }

    // MARK: Sending

    /// starts monitoring for gasEstimateUpdated event for the pending gas estimation request
    /// and starts a timeout timer in case events are not received
    private func waitForGasEstimation(for tx: EthereumTransfer, gasEstimate: UInt256?, completion: @escaping (GasEstimationResult) -> Void) {
        assert(pendingGasEstimate == nil && pendingSend == nil && sendTimeoutTimer == nil)
        pendingGasEstimate = GasEstimateRequest(tx: tx, gasEstimate: gasEstimate, completion: completion)
        DispatchQueue.main.async {
            self.sendTimeoutTimer = Timer.scheduledTimer(withTimeInterval: self.transactionSendTimeout, repeats: false) { [weak self] _ in
                guard let `self` = self else { return }
                assert(self.pendingGasEstimate != nil)
                self.pendingGasEstimate?.completion(.failure(.timedOut))
                self.stopWaitingForSend()
            }
        }
    }

    /// starts monitoring for transfer events related to the pending send
    /// and starts a timeout timer in case events are not received
    private func waitForSend(_ tx: EthereumTransfer, completion: @escaping (SendTransactionResult) -> Void) {
        assert(pendingGasEstimate == nil && pendingSend == nil && sendTimeoutTimer == nil)
        pendingSend = OutgoingTransaction(tx: tx, completion: completion)
        DispatchQueue.main.async {
            self.sendTimeoutTimer = Timer.scheduledTimer(withTimeInterval: self.transactionSendTimeout, repeats: false) { [weak self] _ in
                guard let `self` = self else { return }
                assert(self.pendingSend != nil)
                self.pendingSend?.completion(.failure(.timedOut))
                self.stopWaitingForSend()
            }
        }
    }

    private func stopWaitingForSend() {
        DispatchQueue.main.async {
            self.pendingGasEstimate = nil
            self.pendingSend = nil
            self.sendTimeoutTimer = nil
        }
    }
}

// MARK: - EthereumClient

// The EthereumClient callbacks are triggered by Core to make network requests or propagate wallet events
extension EthWalletManager: EthereumClient {
    
    func getGasEstimate(wallet: EthereumWallet, tid: EthereumTransferId, from: String, to: String, amount: String, data: String, completion: @escaping (String) -> Void) {
        let transfer = node.findTransaction(currency: wallet.currency, identifier: tid)
        
        // skip request if gas estimate was already provided
        if let gasLimit = pendingGasEstimate?.gasEstimate {
            print("[EWM] using specified gas estimate for \(transfer.currency.code) transfer (\(transfer.hash)): \(gasLimit.string(decimals: 10))")
            completion(gasLimit.hexString)
            stopWaitingForSend()
            return
        }

        print("[EWM] getting gas estimate for \(transfer.currency.code) transfer")
        var params = TransactionParams(from: from, to: to)
        params.value = UInt256(hexString: amount)
        params.data = data
        apiClient.estimateGas(transaction: params) { result in
            switch result {
            case .success(let value):
                print("  ↳ gas estimate: \(value.asUInt64)")
                completion(value.hexString)
            case .error(let error):
                print("[EWM] estimateGas error: \(error.localizedDescription)")
            }
        }
    }
    
    func getBalance(wallet: EthereumWallet, address: String, completion: @escaping (String) -> Void) {
        let currency = wallet.currency
        
        if let token = currency as? ERC20Token {
            guard tokens.contains(token) else { return } // skip tokens not in the wallet
            apiClient.getTokenBalance(address: address, token: token) { result in
                switch result {
                case .success(let value):
                    completion(value)
                case .error(let error):
                    print("[EWM] getBalance error: \(error.localizedDescription)")
                }
            }
        } else {
            apiClient.getBalance(address: address) { result in
                switch result {
                case .success(let value):
                    completion(value)
                case .error(let error):
                    print("[EWM] getBalance error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func submitTransaction(wallet: EthereumWallet,
                           tid: EthereumTransferId,
                           rawTransaction: String,
                           completion: @escaping SubmitTransactionHandler) {
        apiClient.sendRawTransaction(rawTx: rawTransaction) { result in
            completion(result)
        }
    }
    
    func getTransactions(address: String, blockStart: UInt64, blockStop: UInt64, completion: @escaping TransactionsHandler) {
        apiClient.getEthTxList(address: address, fromBlock: blockStart, toBlock: blockStop) { result in
            completion(result) // imports transaction json data into core
            if case .error(let error) = result {
                print("[EWM] getTransactions error: \(error.localizedDescription)")
            }
        }
    }
    
    func getLogs(address: String,
                 event: String,
                 blockStart: UInt64,
                 blockStop: UInt64,
                 completion: @escaping LogsHandler) {
        apiClient.getTokenTransferLogs(address: address, contractAddress: nil, fromBlock: blockStart, toBlock: blockStop) { result in
            completion(result) // imports logs json data into core
            if case .error(let error) = result {
                print("[EWM] getLogs error: \(error.localizedDescription)")
            }
        }
    }
    
    func getBlockNumber(completion: @escaping EthereumClient.AmountHandler) {
        apiClient.getLastBlockNumber { result in
            switch result {
            case .success(let blockNumber):
                completion(blockNumber)
            case .error(let error):
                print("[EWM] getLatestBlock error: \(error.localizedDescription)")
            }
        }
    }
    
    func getNonce(address: String, completion: @escaping EthereumClient.AmountHandler) {
        apiClient.getTransactionCount(address: address) { result in
            switch result {
            case .success(let nonce):
                completion(nonce)
            case .error(let error):
                print("[EWM] getNonce error: \(error.localizedDescription)")
            }
        }
    }

    func getBlocks(ewm: EthereumWalletManager, address: String, interests: UInt32, blockStart: UInt64, blockStop: UInt64, rid: Int32) {
        assertionFailure("not implemented")
    }

    func getTokens(ewm: EthereumWalletManager, rid: Int32) {
        assertionFailure("not implemented")
    }

    func getGasPrice(wallet: EthereumWallet, completion: @escaping (String) -> Void) {
        // unused - gas price is set by the FeeUpdater
        assertionFailure()
    }

    // MARK: Events

    func handleEWMEvent(ewm: EthereumWalletManager, event: EthereumEWMEvent) {
        print("[EWM] node event: \(event)")
        switch event {
        case .sync_started:
            syncState[Currencies.eth.code]?.willBeginSync()
            tokens.forEach { syncState[$0.code]?.willBeginSync() }

        case .sync_stopped:
            syncState[Currencies.eth.code]?.didFinishSync()
            tokens.forEach { syncState[$0.code]?.didFinishSync() }

        default:
            break
        }
    }

    func handleWalletEvent(ewm: EthereumWalletManager, wallet: EthereumWallet, event: EthereumWalletEvent) {
        print("[EWM] \(wallet.currency.code) wallet event: \(event)")
        switch event {
        case .created:
            syncState[wallet.currency.code]?.didCreateWallet()
            // set initial balance since balance updated event is not triggered for token wallets with no tx history
            DispatchQueue.main.async {
                Store.perform(action: WalletChange(wallet.currency).setBalance(wallet.balance))
            }
        case .balanceUpdated:
            syncState[wallet.currency.code]?.didFinishSync()
            DispatchQueue.main.async {
                Store.perform(action: WalletChange(wallet.currency).setBalance(wallet.balance))
            }
        default:
            break
        }
    }

    func handleTransferEvent(ewm: EthereumWalletManager, wallet: EthereumWallet, transfer: EthereumTransfer, event: EthereumTransferEvent) {
        print("[EWM] \(transfer.currency.code) transfer \(transfer.hash) event: \(event)")

        if let pendingGasEstimate = pendingGasEstimate, pendingGasEstimate.tx.identifier == transfer.identifier, event == .gasEstimateUpdated {
            //print("  ↳ gas estimate updated: \(transfer.gasLimit)")
            stopWaitingForSend()
            pendingGasEstimate.completion(.success)
            return
        }

        if let pendingSend = pendingSend, transfer.hash == pendingSend.tx.hash {
            print("  ↳ pending send tx event: \(event)")
            switch event {

            case .submitted: // TODO: handle included ?
                guard let accountAddress = address else { return assertionFailure() }
                let currency = pendingSend.tx.currency

                // token transfers result in two transactions being created, one ETH and one ERC20, with the same hash
                // wait for 2 submitted events to respond with both transaction models
                if let token = currency as? ERC20Token {
                    if token.matches(transfer.currency) {
                        assert(transfer.identifier == pendingSend.tx.identifier)
                        // this event is for the token transfer
                        self.pendingSend!.tokenTransferSubmitted = true
                        self.pendingSend!.txRawHex = wallet.rawTransactionHexEncoded(transfer)
                    } else {
                        // this event is for the associated ETH transaction
                        self.pendingSend!.associatedTx = transfer
                    }

                    if let associatedEthTx = self.pendingSend!.associatedTx, self.pendingSend!.tokenTransferSubmitted {
                        let pendingEthTx = EthTransaction(tx: associatedEthTx,
                                                          accountAddress: accountAddress,
                                                          kvStore: kvStore,
                                                          rate: nil)
                        let pendingTokenTx = ERC20Transaction(tx: pendingSend.tx,
                                                              accountAddress: accountAddress,
                                                              token: token,
                                                              kvStore: kvStore,
                                                              rate: nil)
                        let txRawHex = self.pendingSend!.txRawHex ?? ""
                        pendingSend.completion(.success((tx: pendingEthTx, tokenTx: pendingTokenTx, rawTx: txRawHex)))
                        stopWaitingForSend()
                    }
                } else {
                    let pendingEthTx = EthTransaction(tx: transfer,
                                                      accountAddress: accountAddress,
                                                      kvStore: kvStore,
                                                      rate: nil)
                    let txRawHex = wallet.rawTransactionHexEncoded(transfer) ?? ""
                    pendingSend.completion(.success((tx: pendingEthTx, tokenTx: nil, rawTx: txRawHex)))
                    stopWaitingForSend()
                }

            case .errored:
                let error = transfer.error
                print("  ↳ pending send tx error: \(error)")
                pendingSend.completion(.failure(.publishError(error)))
                stopWaitingForSend()

            case .created, .signed:
                break

            default:
                assertionFailure("unexpected event for a pending send")
            }
        }
    }

    func handlePeerEvent(ewm: EthereumWalletManager, event: EthereumPeerEvent) {
        print("[EWM] peer event: \(event)")
    }

    func handleTokenEvent(ewm: EthereumWalletManager, token: ERC20Token, event: EthereumTokenEvent) {
        print("[EWM] token (\(token.code)) \(event)")
        switch event {
        case .created:
            if tokens.contains(token), node.wallet(for: token) == nil {
                createWallet(token)
            }
        case .deleted:
            if tokens.contains(token) {
                assertionFailure("token with active wallet deleted")
            }
        }
    }
}

// MARK: - Sync State

extension EthWalletManager {
    class WalletSyncState {
        enum SyncState {
            case waitingForInitialSync
            case initialSync
            case silentSync
            case idle
        }

        private let currency: Currency
        private var timeoutTimer: Timer? {
            didSet {
                timeoutTimer?.invalidate()
            }
        }
        private let timeoutSeconds = 1.0 // seconds to wait sync indicator is shown
        private var state: SyncState = .waitingForInitialSync

        init(currency: Currency) {
            self.currency = currency
        }

        func didCreateWallet() {
            guard state == .waitingForInitialSync else { return }
            DispatchQueue.main.async {
                Store.perform(action: WalletChange(self.currency).setProgress(progress: -1.0, timestamp: 0))
                Store.perform(action: WalletChange(self.currency).setSyncingState(.connecting))
            }
        }

        func willBeginSync() {
            switch state {
            case .waitingForInitialSync:
                state = .initialSync
                DispatchQueue.main.async {
                    self.timeoutTimer = Timer.scheduledTimer(withTimeInterval: self.timeoutSeconds, repeats: false) { [unowned self] _ in
                        self.showSyncIndicator()
                    }
                }
            case .idle:
                state = .silentSync
            default:
                break
            }
        }

        func didFinishSync() {
            state = .idle
            DispatchQueue.main.async {
                Store.perform(action: WalletChange(self.currency).setProgress(progress: 1.0, timestamp: 0))
                Store.perform(action: WalletChange(self.currency).setSyncingState(.success))
            }
        }

        private func showSyncIndicator() {
            guard state == .initialSync else { return assertionFailure() }
            DispatchQueue.main.async {
                Store.perform(action: WalletChange(self.currency).setProgress(progress: -1.0, timestamp: 0))
                Store.perform(action: WalletChange(self.currency).setSyncingState(.syncing))
            }
        }
    }
}
