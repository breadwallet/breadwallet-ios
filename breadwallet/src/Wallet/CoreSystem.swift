//
//  CoreSystem.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2019-04-16.
//  Copyright © 2019 Breadwinner AG. All rights reserved.
//

import Foundation
import BRCrypto
import UIKit

// swiftlint:disable type_body_length
class CoreSystem: Subscriber, Trackable {
    
    private var system: System?
    private let queue = DispatchQueue(label: "com.brd.CoreSystem", qos: .utility)

    // MARK: Wallets + Currencies

    private(set) var assetCollection: AssetCollection?
    /// All supported currencies
    private(set) var currencies = [CurrencyId: Currency]()
    /// Active wallets
    private(set) var wallets = [CurrencyId: Wallet]()

    func wallet(for currency: Currency) -> Wallet? {
        return wallets[currency.uid]
    }

    // MARK: Lifecycle

    init() {
        Store.subscribe(self, name: .optInSegWit) { [weak self] _ in
            guard let `self` = self else { return }
            self.queue.async {
                guard let btc = Currencies.btc.instance,
                    let btcWalletManager = self.wallet(for: btc)?.manager else { return }
                btcWalletManager.addressScheme = .btcSegwit
                print("[SYS] Bitcoin SegWit address scheme enabled")
            }
        }

        Reachability.addDidChangeCallback { [weak self] isReachable in
            guard let `self` = self, let system = self.system else { return }
            system.setNetworkReachable(isReachable)
            isReachable ? self.connect() : self.disconnect()
        }
    }

    /// Creates and configures the System with the Account and BDB authentication token.
    func create(account: Account, authToken: String) {
        guard let kvStore = Backend.kvStore else { return assertionFailure() }
        print("[SYS] create | account timestamp: \(account.timestamp)")
        assert(self.system == nil)

        let backend = BlockChainDB(session: URLSession.shared,
                                   bdbBaseURL: "https://\(C.bdbHost)",
            bdbDataTaskFunc: { (session, request, completion) -> URLSessionDataTask in
                
                var req = request
                req.authorize(withToken: authToken)
                //TODO:CRYPTO does not handle 401, other headers, redirects
                return session.dataTask(with: req, completionHandler: completion)
        },
            apiBaseURL: "https://\(C.backendHost)",
            apiDataTaskFunc: { (_, req, completion) -> URLSessionDataTask in
                return Backend.apiClient.dataTaskWithRequest(req,
                                                             authenticated: Backend.isConnected,
                                                             retryCount: 0,
                                                             responseQueue: self.queue,
                                                             handler: completion)
        })

        try? FileManager.default.createDirectory(atPath: C.coreDataDirURL.path, withIntermediateDirectories: true, attributes: nil)
        
        self.system = System.create(listener: self,
                                    account: account,
                                    onMainnet: !E.isTestnet,
                                    path: C.coreDataDirURL.path,
                                    query: backend,
                                    listenerQueue: self.queue)

        if let system = self.system {
            System.wipeAll(atPath: C.coreDataDirURL.path, except: [system])
        }
        
        Backend.apiClient.getCurrencyMetaData { currencyMetaData in
            self.queue.async {
                self.assetCollection = AssetCollection(kvStore: kvStore,
                                                       allTokens: currencyMetaData,
                                                       changeHandler: self.updateWalletStates)
                let currencyModels = currencyMetaData.values.compactMap {
                    System.asBlockChainDBModelCurrency(uids: $0.uid.rawValue,
                                                       name: $0.name,
                                                       code: $0.code,
                                                       type: $0.type,
                                                       decimals: $0.decimals)
                }
                self.system?.configure(withCurrencyModels: currencyModels)
            }
        }
    }

    /// Connects all active wallet managers. Used on foreground and when reachability is restored.
    func connect() {
        queue.async {
            print("[SYS] connect")
            guard let system = self.system else { return assertionFailure() }
            system.managers
                .filter { self.isWalletManagerNeeded($0) }
                .forEach { $0.connect(using: $0.customPeer) }
        }
    }

    /// Disconnects all wallet managers. Used on background and when reachability is lost.
    func disconnect() {
        queue.async {
            print("[SYS] disconnect")
            guard let system = self.system else { return }
            system.disconnectAll()
        }
    }

    /// Shutdown the system and release resources. Used for account removal.
    func shutdown(completion: (() -> Void)?) {
        queue.async {
            print("[SYS] shutdown / wipe")
            guard let system = self.system else { return assertionFailure() }
            
            System.wipe(system: system)
            
            self.wallets.removeAll()
            self.currencies.removeAll()
            self.system = nil
            
            completion?()
        }
    }

    /// Fetch network fees from backend
    func updateFees() {
        queue.async {
            guard let system = self.system else { return assertionFailure() }
            system.updateNetworkFees { result in
                switch result {
                case .success(let networks):
                    print("[SYS] Fees: updated fees for \(networks.map { $0.name })")
                case .failure(let error):
                    print("[SYS] Fees: failed to update with error: \(error)")
                }
            }
        }
    }

    /// Re-sync blockchain from specified depth
    func rescan(walletManager: WalletManager, fromDepth depth: WalletManagerSyncDepth) {
        queue.async {
            walletManager.connect(using: walletManager.customPeer)
            walletManager.syncToDepth(depth: depth)
            DispatchQueue.main.async {
                walletManager.network.currencies
                    .compactMap { self.currencies[$0.uid] }
                    .forEach { Store.perform(action: WalletChange($0).setIsRescanning(true)) }
            }
        }
    }

    // MARK: - Core Wallet Management

    /// Adds Currency models for all currencies supported by the Network and enabled in the asset collection.
    private func addCurrencies(for network: Network) {
        guard let assetCollection = assetCollection else { return assertionFailure() }
        for coreCurrency in network.currencies {
            guard currencies[coreCurrency.uid] == nil else { return assertionFailure() }
            guard let metaData = assetCollection.allAssets[coreCurrency.uid] else {
                print("[SYS] unknown currency omitted: \(network.currency.code) / \(coreCurrency.uid)")
                continue
            }

            guard let units = network.unitsFor(currency: coreCurrency),
                let baseUnit = network.baseUnitFor(currency: coreCurrency),
                let defaultUnit = network.defaultUnitFor(currency: coreCurrency),
                let currency = Currency(core: coreCurrency,
                                        network: network,
                                        metaData: metaData,
                                        units: units,
                                        baseUnit: baseUnit,
                                        defaultUnit: defaultUnit) else {
                                            assertionFailure("unable to create view model for \(coreCurrency.code)")
                                            continue
            }
            currencies[coreCurrency.uid] = currency
        }
        print("[SYS] \(network) currencies: \(network.currencies.map { $0.code }.joined(separator: ","))")
    }

    /// Creates a wallet manager for the network. Wallets are added asynchronously by Core for all network currencies.
    private func setupWalletManager(for network: Network) {
        guard let system = system, let assetCollection = assetCollection else { return assertionFailure() }
        guard let currency = currencies[network.currency.uid] else {
            print("[SYS] \(network) wallet manager not created. \(network.currency.uid) not supported.")
            return
        }

        if system.migrateRequired(network: network) {
            self.migrateLegacyDatabase(network: network)
        }
        
        // networks tokens for which wallets are needed
        let requiredTokens = network.currencies.filter { assetCollection.isEnabled($0.uid) }

        var addressScheme: AddressScheme
        if currency.isBitcoin {
            addressScheme = UserDefaults.hasOptedInSegwit ? .btcSegwit : .btcLegacy
        } else {
            addressScheme = system.defaultAddressScheme(network: network)
        }

        var mode = self.connectionMode(for: currency)
        if !system.supportsMode(network: network, mode) {
            assertionFailure("invalid wallet manager mode \(mode) for \(network.currency.code)")
            mode = system.defaultMode(network: network)
        }
        print("[SYS] creating wallet manager for \(network). active wallets: \(requiredTokens.map { $0.code }.joined(separator: ","))")
        let result = system.createWalletManager(network: network,
                                                mode: mode,
                                                addressScheme: addressScheme,
                                                currencies: requiredTokens)
        assert(result, "failed to create \(network) wallet manager")
    }

    /// Migrates the old sqlite persistent storage data to Core, if present.
    /// Deletes old database after successful migration.
    private func migrateLegacyDatabase(network: Network) {
        guard let system = system,
            let currency = currencies[network.currency.uid],
            (currency.isBitcoin || currency.isBitcoinCash) else { return assertionFailure() }
        let fm = FileManager.default
        let filename = currency.isBitcoin ? "BreadWallet.sqlite" : "BreadWallet-bch.sqlite"
        let docsUrl = try? fm.url(for: .documentDirectory,
                                  in: .userDomainMask,
                                  appropriateFor: nil,
                                  create: false)
        guard let dbPath = docsUrl?.appendingPathComponent(filename).path,
            fm.fileExists(atPath: dbPath) else { return }

        do {
            let db = CoreDatabase()
            try db.openDatabase(path: dbPath)
            defer { db.close() }

            let txBlobs = db.loadTransactions()
            let blockBlobs = db.loadBlocks()
            let peerBlobs = db.loadPeers()

            print("[SYS] migrating \(network.currency.code) database: \(txBlobs.count) txns / \(blockBlobs.count) blocks / \(peerBlobs.count) peers")

            try system.migrateStorage(network: network,
                                      transactionBlobs: txBlobs,
                                      blockBlobs: blockBlobs,
                                      peerBlobs: peerBlobs)
            print("[SYS] \(network.currency.code) database migrated")
        } catch let error {
            print("[SYS] database migration failed: \(error)")
        }
        // delete the old database to avoid future migration attempts
        try? fm.removeItem(atPath: dbPath)
    }

    /// Adds a Wallet model for the Core Wallet if it is enabled in the asset collection.
    private func addWallet(_ coreWallet: BRCrypto.Wallet) -> Wallet? {
        guard let assetCollection = assetCollection,
            let currency = currencies[coreWallet.currency.uid],
            wallets[coreWallet.currency.uid] == nil else {
                assertionFailure()
                return nil
        }

        guard assetCollection.isEnabled(currency.uid) else {
            print("[SYS] hidden wallet not added: \(currency.code)")
            return nil
        }

        let wallet = Wallet(core: coreWallet,
                            currency: currency,
                            system: self)
        wallets[coreWallet.currency.uid] = wallet
        return wallet
    }
    
    /// Triggered by Core wallet deleted event -- normally never triggered
    private func removeWallet(_ coreWallet: BRCrypto.Wallet) {
        guard wallets[coreWallet.currency.uid] != nil else { return assertionFailure() }
        wallets[coreWallet.currency.uid] = nil
        updateWalletStates()
    }
    
    /// Requests the wallet managers to create wallets for all enabled currencies.
    /// Wallet creation is asynchronous and triggers a wallet `created` event.
    private func requestCoreWalletCreation() {
        guard let managers = system?.managers,
            let assetCollection = assetCollection else { return }
        
        managers.forEach { manager in
            let added = manager.network.currencies
                .filter { assetCollection.isEnabled($0.uid) && wallets[$0.uid] == nil }
                .filter { manager.registerWalletFor(currency: $0) == nil } // nil returned if wallet will be created
            if !added.isEmpty {
                print("[SYS] creating wallets for \(added.map { $0.code }.joined(separator: ","))")
            }
        }
    }

    /// Reset the active wallets to match the asset collection by adding/removing wallets
    private func updateActiveWallets() {
        guard let assetCollection = assetCollection else { return }
        let enabledIds = Set(assetCollection.enabledAssets.map { $0.uid })
        let newWallets = enabledIds
            .filter { wallets[$0] == nil }
            .compactMap { coreWallet($0) }
            .compactMap { addWallet($0) }
            .map { ($0.currency.uid, $0) }
        wallets = wallets
            .filter { enabledIds.contains($0.key) } // remove disabled wallets
            .merging(newWallets, uniquingKeysWith: { (_, new) in new }) // add enabled wallets
    }

    /// Connect wallet managers with any enabled wallets and disconnect those with no enabled wallets.
    private func updateWalletManagerConnections() {
        guard let managers = system?.managers,
            let assetCollection = assetCollection else { return }
        let enabledIds = Set(assetCollection.enabledAssets.map { $0.uid })

        var activeManagers = [WalletManager]()
        var inactiveManagers = [WalletManager]()

        for manager in managers {
            if Set(manager.network.currencies.map { $0.uid }).isDisjoint(with: enabledIds) {
                inactiveManagers.append(manager)
            } else {
                activeManagers.append(manager)
            }
        }

        activeManagers.forEach {
            print("[SYS] connecting \($0.network.currency.code) wallet manager")
            $0.connect(using: $0.customPeer)
        }

        inactiveManagers.forEach {
            print("[SYS] disconnecting \($0.network.currency.code) wallet manager")
            $0.disconnect()
        }
    }

    // MARK: Connection Mode

    func isModeSupported(_ mode: WalletConnectionMode, for network: Network) -> Bool {
        return system?.supportsMode(network: network, mode) ?? false
    }

    func setConnectionMode(_ mode: WalletConnectionMode, forWalletManager wm: WalletManager) {
        guard let system = self.system, system.supportsMode(network: wm.network, mode) else { return assertionFailure() }
        queue.async {
            wm.disconnect()
            wm.mode = mode
            wm.connect(using: wm.customPeer)
        }
    }

    func connectionMode(for currency: Currency) -> WalletConnectionMode {
        guard let networkCurrency = currency.tokenType == .native ? currency : currencies[currency.network.currency.uid] else {
            assertionFailure()
            return .api_only
        }
        guard let kv = Backend.kvStore,
            let walletInfo = WalletInfo(kvStore: kv) else {
                assertionFailure()
                return WalletConnectionSettings.defaultMode(for: networkCurrency)
        }
        let settings = WalletConnectionSettings(system: self, kvStore: kv, walletInfo: walletInfo)
        return settings.mode(for: networkCurrency)
    }

    // MARK: - AssetCollection / WalletState Management
    
    func resetToDefaultCurrencies() {
        guard let assetCollection = assetCollection else { return }
        assetCollection.resetToDefaultCollection()
        assetCollection.saveChanges() // triggers updateWalletStates
    }
    
    /// Returns true if a wallet for a network native currency is required as a dependency for other active wallets.
    func isWalletRequired(for currencyId: CurrencyId) -> Bool {
        guard let assetCollection = assetCollection,
            let currency = currencies[currencyId],
            currency.tokenType == .native else { return false }
        return !assetCollection.enabledAssets
            .compactMap { self.currencies[$0.uid] }
            .filter { $0.uid != currency.uid && $0.network == currency.network }
            .isEmpty
    }
    
    func walletBalance(currencyId: CurrencyId) -> Amount? {
        if let balance = wallets[currencyId]?.balance {
            return balance
        } else if let coreBalance = coreWallet(currencyId)?.balance, let currency = currencies[currencyId] {
            return Amount(cryptoAmount: coreBalance, currency: currency)
        } else {
            return nil
        }
    }

    /// Creates placeholder WalletStates for all enabled currencies which do not have a Wallet yet.
    private var placeholderWalletStates: [CurrencyId: WalletState] {
        guard let assetCollection = assetCollection else { assertionFailure(); return [:] }
        return assetCollection.enabledAssets
            .filter { self.wallets[$0.uid] == nil }
            .compactMap { self.currencies[$0.uid] }
            .reduce(into: [CurrencyId: WalletState](), { (walletStates, currency) in
                guard let displayOrder = assetCollection.displayOrder(for: currency.metaData) else { return }
                walletStates[currency.uid] = WalletState.initial(currency, displayOrder: displayOrder).mutate(syncState: .connecting)
            })
    }

    /// Adds or replaces WalletState for a Wallet.
    private func addWalletState(for wallet: Wallet) {
        guard let displayOrder = assetCollection?.displayOrder(for: wallet.currency.metaData) else { return assertionFailure("wallet not enabled") }
        // reading+writing Store.state must be on main thread
        DispatchQueue.main.async {
            let walletState = self.walletState(for: wallet, displayOrder: displayOrder)
            Store.perform(action: WalletChange(wallet.currency).set(walletState))
        }
    }
    
    /// Sets the wallet states to match changes to the asset collection and Core wallets.
    /// Triggered by AssetCollection.saveChanges on main thread.
    private func updateWalletStates() {
        queue.async {
            guard let assetCollection = self.assetCollection else { return }
            print("[SYS] updating wallets")
            
            self.updateActiveWallets()
            self.updateWalletManagerConnections()
            self.requestCoreWalletCreation()
            
            // reading+writing Store.state must be on main thread
            DispatchQueue.main.async {
                // combine and set active wallet states and placeholder (pending wallet creation) wallet states
                let walletStates: [CurrencyId: WalletState] = assetCollection.enabledAssets
                    .compactMap { self.wallets[$0.uid] }
                    .reduce(into: [CurrencyId: WalletState](), { (walletStates, wallet) in
                        let currency = wallet.currency
                        guard let displayOrder = assetCollection.displayOrder(for: currency.metaData) else { return }
                        walletStates[currency.uid] = self.walletState(for: wallet, displayOrder: displayOrder)
                    })
                    .merging(self.placeholderWalletStates, uniquingKeysWith: { (existing, _) in existing })
                Store.perform(action: ManageWallets.SetWallets(walletStates))
                Backend.updateExchangeRates()
            }
        }
    }
    
    private func coreWallet(_ currencyId: CurrencyId) -> BRCrypto.Wallet? {
        return system?.wallets.first(where: { $0.currency.uid == currencyId })
    }
    
    private func walletState(for wallet: Wallet, displayOrder: Int) -> WalletState {
        assert(Thread.isMainThread)
        if let existing = Store.state.wallets[wallet.currency.uid] {
            return existing.mutate(wallet: wallet, displayOrder: displayOrder, syncState: .success, balance: wallet.balance)
        } else {
            return WalletState.initial(wallet.currency, wallet: wallet, displayOrder: displayOrder)
                .mutate(syncState: .success, balance: wallet.balance)
        }
    }

    /// Returns true of any of the enabled assets in the asset collection are dependent on the wallet manager
    private func isWalletManagerNeeded(_ manager: WalletManager) -> Bool {
        guard let assetCollection = assetCollection else { assertionFailure(); return false }
        let enabledCurrencyIds = Set(assetCollection.enabledAssets.map { $0.uid })
        let supportedCurrencyIds = manager.network.currencies.map { $0.uid }
        return !Set(supportedCurrencyIds).isDisjoint(with: enabledCurrencyIds)
    }
    
    // Shows the network activity indicator and prevents
    // the app from being backgrounded while syncing
    private func startActivity() {
        UIApplication.shared.isIdleTimerDisabled = true
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
    }

    private func endActivity() {
        UIApplication.shared.isIdleTimerDisabled = false
        UIApplication.shared.isNetworkActivityIndicatorVisible = false
    }
    
    // MARK: Wallet ID
    
    // walletID identifies a wallet by the ethereum public key
    // 1. compute the sha256(address[0]) -- note address excludes the "0x" prefix
    // 2. take the first 10 bytes of the sha256 and base32 encode it (lowercasing the result)
    // 3. split the result into chunks of 4-character strings and join with a space
    //
    // this provides an easily human-readable (and verbally-recitable) string that can
    // be used to uniquely identify this wallet.
    //
    // the user may then provide this ID for later lookup in associated systems
    private func walletID(address: String) -> String? {
        if let small = address.withoutHexPrefix.data(using: .utf8)?.sha256[0..<10].base32.lowercased() {
            return stride(from: 0, to: small.count, by: 4).map {
                let start = small.index(small.startIndex, offsetBy: $0)
                let end = small.index(start, offsetBy: 4, limitedBy: small.endIndex) ?? small.endIndex
                return String(small[start..<end])
                }.joined(separator: " ")
        }
        return nil
    }
}

// MARK: - SystemListener

// callbacks execute on CoreSystem.queue
extension CoreSystem: SystemListener {

    func handleSystemEvent(system: System, event: SystemEvent) {
        //print("[SYS] system event: \(event)")
        switch event {
        case .created:
            break

        case .networkAdded:
            break

        // after all networks are added
        case .discoveredNetworks(let networks):
            guard !E.isRunningTests else { return }
            let filteredNetworks = networks.filter { $0.isMainnet == !E.isTestnet }
            filteredNetworks.forEach { addCurrencies(for: $0) }
            DispatchQueue.main.async {
                Store.perform(action: ManageWallets.AddWallets(self.placeholderWalletStates))
                Backend.updateExchangeRates()
            }
            filteredNetworks.forEach { setupWalletManager(for: $0) }

        case .managerAdded(let manager):
            if self.isWalletManagerNeeded(manager) {
                manager.connect(using: manager.customPeer)
            }
        }
    }

    func handleManagerEvent(system: System, manager: BRCrypto.WalletManager, event: WalletManagerEvent) {
        //print("[SYS] \(manager.network) manager event: \(event)")
        switch event {
        case .created:
            break
        case .changed: // (let oldState, let newState):
            break
        case .deleted:
            break
        case .walletAdded: // (let wallet):
            break
        case .walletChanged: // (let wallet):
            break
        case .walletDeleted: // (let wallet):
            break

        case .syncStarted:
            DispatchQueue.main.async {
                // only show the initial sync for API-mode wallets
                let isP2Psync = manager.mode == .p2p_only
                manager.network.currencies.compactMap { self.currencies[$0.uid] }
                    .filter { isP2Psync || (Store.state[$0]?.syncState == .connecting) }
                    .forEach { Store.perform(action: WalletChange($0).setSyncingState(.syncing)) }
                if isP2Psync {
                    self.startActivity()
                }
            }

        case .syncProgress(let timestamp, let percentComplete):
            guard manager.mode == .p2p_only else { break }
            DispatchQueue.main.async {
                manager.network.currencies.compactMap { self.currencies[$0.uid] }.forEach {
                    let seconds = UInt32(timestamp?.timeIntervalSince1970 ?? 0)
                    let progress = Float(percentComplete / 100.0)
                    Store.perform(action: WalletChange($0).setProgress(progress: progress, timestamp: seconds))
                }
            }

        case .syncEnded(let reason):
            DispatchQueue.main.async {
                var syncState: SyncState
                var isComplete: Bool = false
                
                switch reason {
                case .complete, .unknown:
                    syncState = .success
                    isComplete = true
                        
                case .requested: // disconnect/background
                    syncState = .connecting
                    
                case .posix(let errno, let message):
                    let messagePayload = "\(message ?? "") (\(errno))"
                    print("[SYS] \(manager.network) sync error: \(messagePayload)")
                    self.saveEvent("event.syncErrorMessage", attributes: ["network": manager.network.currency.code, "message": messagePayload])
                    syncState = .connecting
                    // retry by reconnecting
                    self.queue.asyncAfter(deadline: .now() + .seconds(1)) {
                        manager.connect(using: manager.customPeer)
                    }
                }
                
                manager.network.currencies.compactMap { self.currencies[$0.uid] }.forEach {
                    if isComplete {
                        Store.perform(action: WalletChange($0).setIsRescanning(false))
                        if let balance = self.wallets[$0.uid]?.balance {
                            Store.perform(action: WalletChange($0).setBalance(balance))
                        }
                    }
                    Store.perform(action: WalletChange($0).setSyncingState(syncState))
                }
                
                // If there are no more p2p wallets syncing, hide
                // the network activity indicator and resume
                // the idle timer
                let syncingCount = system.managers
                    .filter { $0.mode == .p2p_only }
                    .filter { $0.state == .syncing || $0.state == .created }.count
                if syncingCount == 0 {
                    self.endActivity()
                }
            }

        case .blockUpdated: // (let height):
            break
        }
    }

    func handleWalletEvent(system: System, manager: BRCrypto.WalletManager, wallet: BRCrypto.Wallet, event: WalletEvent) {
        //print("[SYS] \(manager.network) wallet event: \(wallet.currency.code) \(event)")
        switch event {
        case .created:
            if let wallet = addWallet(wallet) {
                addWalletState(for: wallet)
            }
            // generate wallet ID from Ethereum address
            if wallet.currency.uid == Currencies.eth.uid,
                let walletID = self.walletID(address: wallet.target.description) {
                DispatchQueue.main.async {
                    Store.perform(action: WalletID.Set(walletID))
                }
            }

        case .deleted:
            self.removeWallet(wallet)

        default:
            self.wallets[wallet.currency.uid]?.handleWalletEvent(event)
        }
    }

    func handleTransferEvent(system: System, manager: BRCrypto.WalletManager, wallet: BRCrypto.Wallet, transfer: Transfer, event: TransferEvent) {
        guard let wallet = self.wallets[wallet.currency.uid] else { return }
        print("[SYS] \(manager.network) transfer \(event): \(wallet.currency.code) \(transfer.hash?.description.truncateMiddle() ?? "")")
        wallet.handleTransferEvent(event, transfer: transfer)
    }

    func handleNetworkEvent(system: System, network: Network, event: NetworkEvent) {
        print("[SYS] network event: \(event) (\(network))")
    }
}

// MARK: - Extensions

extension WalletManager {
    var customPeer: NetworkPeer? {
        guard network.currency.uid == Currencies.btc.uid,
            let address = UserDefaults.customNodeIP else { return nil }
        let port = UInt16(UserDefaults.customNodePort ?? C.standardPort)
        return network.createPeer(address: address, port: port, publicKey: nil)
    }
}

extension WalletManagerEvent: CustomStringConvertible {
    public var description: String {
        switch self {
        case .created:
            return "created"
        case .changed(let oldState, let newState):
            return "changed(\(oldState) -> \(newState))"
        case .deleted:
            return "deleted"
        case .walletAdded(let wallet):
            return "walletAdded(\(wallet.currency.code))"
        case .walletChanged(let wallet):
            return "walletChanged(\(wallet.currency.code))"
        case .walletDeleted(let wallet):
            return "walletDeleted(\(wallet.currency.code))"
        case .syncStarted:
            return "syncStarted"
        case .syncProgress(let percentComplete):
            return "syncProgress(\(percentComplete))"
        case .syncEnded(let reason):
            return "syncEnded(\(reason))"
        case .blockUpdated(let height):
            return "blockUpdated(\(height))"
        }
    }
}

extension Address {
    var sanitizedDescription: String {
        return description
            .removing(prefix: "bitcoincash:")
            .removing(prefix: "bchtest:")
    }
}

//TODO:CRYPTO hook up to notifications?
// MARK: - Sounds
/*
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
*/
