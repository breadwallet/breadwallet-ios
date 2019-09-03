//
//  CoreSystem.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2019-04-16.
//  Copyright © 2019 Breadwinner AG. All rights reserved.
//

import Foundation
import BRCrypto

class CoreSystem: Subscriber {
    
    private var system: System?

    private let queue = DispatchQueue(label: "com.brd.CoreSystem")

    // MARK: Wallets + Currencies

    private(set) var assetCollection: AssetCollection?
    
    private var wallets = [BRCrypto.Currency: Wallet]()

    // Currency view models indexed by Core Currency
    fileprivate var currencies = [BRCrypto.Currency: Currency]()

    init() {
        Store.subscribe(self, name: .optInSegWit) { [weak self] _ in
            guard let btc = Currencies.btc.instance,
                let btcWalletManager = self?.wallet(for: btc)?.core.manager else { return }
            btcWalletManager.addressScheme = .btcSegwit
            print("[SYS] Bitcoin SegWit address scheme enabled")
        }
    }

    func currency(forCoreCurrency core: BRCrypto.Currency) -> Currency? {
        return currencies[core]
    }

    func wallet(for currency: Currency) -> Wallet? {
        return wallets[currency.core]
    }

    private func connectionMode(for currency: Currency) -> WalletConnectionMode {
        assert(currency.tokenType == .native)
        guard let kv = Backend.kvStore,
            let walletInfo = WalletInfo(kvStore: kv) else {
                assertionFailure()
                return WalletConnectionSettings.defaultMode(for: currency)
        }
        let settings = WalletConnectionSettings(system: self, kvStore: kv, walletInfo: walletInfo)
        return settings.mode(for: currency)
    }

    func isModeSupported(_ mode: WalletConnectionMode, for network: Network) -> Bool {
        return system?.supportsMode(network: network, mode) ?? false
    }
    
    /// Gets the balance for a wallet with matching currency ID, including wallets which are not enabled, if found
    func balance(forCurrencyWithId currencyId: String) -> Amount? {
        guard let system = system,
            let wallet = system.wallets.first(where: { currencyId == $0.currency.uids }),
            let currency = currencies[wallet.currency] else { return nil }
        return Amount(cryptoAmount: wallet.balance, currency: currency)
    }

    /// Adds all currencies supported by the Network and enabled in the asset collection.
    /// This is triggered by the networkAdded event on launch.
    private func addCurrencies(for network: Network) {
        guard let assetCollection = assetCollection else { return assertionFailure() }
        for coreCurrency in network.currencies {
            guard currencies[coreCurrency] == nil else { return assertionFailure() }
            guard let metaData = assetCollection.allAssets[coreCurrency.uids] else {
                print("[SYS] unknown currency omitted: \(network.currency.code) / \(coreCurrency.uids)")
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
            print("[SYS] currency added: \(network) \(currency.code)")
            currencies[coreCurrency] = currency
        }
    }

    // MARK: Lifecycle

    // create -- on launch w/ acount present and wallet unlocked
    func create(account: Account, authToken: String) {
        guard let kvStore = Backend.kvStore else { return assertionFailure() }
        print("[SYS] create | account timestamp: \(account.timestamp)")
        queue.async {
            assert(self.system == nil)
            
            //TODO:CRYPTO cleanup
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
                    return Backend.apiClient.dataTaskWithRequest(req, authenticated: true, retryCount: 0, handler: completion)
            })
            
            self.system = System(listener: self,
                                 account: account,
                                 onMainnet: !E.isTestnet,
                                 path: C.coreDataDirURL.path,
                                 query: backend)
            Backend.apiClient.getCurrencyMetaData { currencyMetaData in
                self.assetCollection = AssetCollection(kvStore: kvStore,
                                                       allTokens: currencyMetaData,
                                                       changeHandler: self.updateWalletStates)
                self.system?.configure()
            }
        }
    }

    // connect/start -- foreground / reachable
    func connect() {
        print("[SYS] connect")
        queue.async {
            guard let system = self.system else { return assertionFailure() }
            system.managers.forEach { $0.connect() }
        }
    }

    // disconnect/stop -- background / unreachable
    func disconnect() {
        print("[SYS] disconnect")
        queue.async {
            guard let system = self.system else { return assertionFailure() }
            system.stop()
        }
    }

    // shutdown -- wallet unlinked / account removed
    func shutdown(completion: (() -> Void)?) {
        print("[SYS] shutdown / wipe")
        queue.async {
            guard let system = self.system else { return assertionFailure() }
            system.stop()
            self.wallets.removeAll()
            self.currencies.removeAll()
            self.system = nil

            let url = C.coreDataDirURL
            do {
                try FileManager.default.removeItem(at: url)
            } catch let error {
                print("[SYS] ERROR removing dir \(url.absoluteString): \(error)")
            }
            
            completion?()
        }
    }
    
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

    /// Migrates the old sqlite persistent storage data to Core, if present.
    /// After successful migration the sqlite database is deleted.
    private func migrateLegacyDatabase(network: Network) {
        guard let system = system,
            let currency = currency(forCoreCurrency: network.currency),
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

    // MARK: Core Wallet Management

    /// Triggered by Core wallet created event
    private func addWallet(_ coreWallet: BRCrypto.Wallet) {
        guard let assetCollection = assetCollection, wallets[coreWallet.currency] == nil else { return assertionFailure() }
        // only add wallets that are enabled in the user's asset collection
        guard let currency = currencies[coreWallet.currency],
            let displayOrder = assetCollection.displayOrder(for: currency.metaData) else {
            print("[SYS] wallet not added: \(coreWallet.currency.code)")
            return
        }
        
        let walletState = initializeWalletState(core: coreWallet, currency: currency, displayOrder: displayOrder)
        DispatchQueue.main.async {
            Store.perform(action: ManageWallets.AddWallets([currency.uid: walletState]))
            Store.perform(action: WalletChange(currency).setSyncingState(.connecting))
            Backend.updateExchangeRates()
        }
    }
    
    /// Triggered by Core wallet deleted event
    private func removeWallet(_ coreWallet: BRCrypto.Wallet) {
        //TODO:CRYPTO when does this happen? can it happen without user intervention?
        guard self.wallets[coreWallet.currency] != nil else { return assertionFailure() }
        self.wallets[coreWallet.currency] = nil
        updateWalletStates()
    }
    
    // MARK: User Wallet Management

    func setConnectionMode(_ mode: WalletConnectionMode, forWalletManager wm: WalletManager) {
        guard let system = self.system, system.supportsMode(network: wm.network, mode) else { return assertionFailure() }
        queue.async {
            wm.disconnect()
            wm.mode = mode
            wm.connect()
        }
    }
    
    func resetToDefaultCurrencies() {
        guard let assetCollection = assetCollection else { return }
        assetCollection.resetToDefaultCollection()
        assetCollection.saveChanges() // triggers updateWalletStates
    }
    
    /// Sets the wallet states to match the asset collection
    private func updateWalletStates() {
        guard let assetCollection = assetCollection else { return }
        var newWallets = [String: WalletState]()
        assetCollection.enabledAssets.enumerated().forEach { i, metaData in
            guard let coreWallet = findCoreWallet(forMetaData: metaData),
                let currency = currencies[coreWallet.currency] else { return print("[SYS] Skipped adding \(metaData.code). Couldn't find core currency.")  }
            if let walletState = Store.state.wallets[currency.uid] {
                newWallets[currency.uid] = walletState.mutate(displayOrder: i)
            } else {
                newWallets[currency.uid] = initializeWalletState(core: coreWallet, currency: currency, displayOrder: i)
            }
        }
        
        DispatchQueue.main.async {
            Store.perform(action: ManageWallets.SetWallets(newWallets))
            Backend.updateExchangeRates()
        }
        
        updateWalletManagerConnections()
    }
    
    private func findCoreWallet(forMetaData metaData: CurrencyMetaData) -> BRCrypto.Wallet? {
        guard let system = system else { return nil }
        guard let wallet = system.wallets.first(where: { $0.currency.uids == metaData.uid }) else {
            print("[SYS] Error couldn't find core wallet for: \(metaData.code).")
            return nil }
        return wallet
    }
    
    private func initializeWalletState(core: BRCrypto.Wallet, currency: Currency, displayOrder: Int) -> WalletState {
        let wallet = Wallet(core: core, currency: currency, system: self)
        wallets[core.currency] = wallet
        return WalletState.initial(currency, wallet: wallet, displayOrder: displayOrder)
    }

    /// Connect wallet managers with any enabled wallets and disconnect those with no enabled wallets.
    private func updateWalletManagerConnections() {
        guard let managers = system?.managers,
            let assetCollection = assetCollection else { return }
        let enabledIds = Set(assetCollection.enabledAssets.map { $0.uid })

        var activeManagers = [WalletManager]()
        var inactiveManagers = [WalletManager]()

        for manager in managers {
            if Set(manager.network.currencies.map { $0.uids }).isDisjoint(with: enabledIds) {
                inactiveManagers.append(manager)
            } else {
                activeManagers.append(manager)
            }
        }

        activeManagers.forEach {
            print("[SYS] connecting \($0.network.currency.code) wallet manager")
            $0.connect()
        }

        inactiveManagers.forEach {
            print("[SYS] disconnecting \($0.network.currency.code) wallet manager")
            $0.disconnect()
        }
    }

    /// Returns true of any of the enabled assets in the asset collection are dependent on the wallet manager
    private func isWalletManagerNeeded(_ manager: WalletManager) -> Bool {
        guard let assetCollection = assetCollection else { assertionFailure(); return false }
        let enabledCurrencyIds = Set(assetCollection.enabledAssets.map { $0.uid })
        let supportedCurrencyIds = manager.network.currencies.map { $0.uids }
        return !Set(supportedCurrencyIds).isDisjoint(with: enabledCurrencyIds)
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

extension CoreSystem: SystemListener {

    func handleSystemEvent(system: System, event: SystemEvent) {
        queue.async {
            print("[SYS] system event: \(event)")
            switch event {
            case .created:
                break

            case .networkAdded(let network):
                // A network was created; create the corresponding wallet manager.
                if network.isMainnet == !E.isTestnet && !E.isRunningTests {
                    print("[SYS] init \(network.isMainnet ? "mainnet" : "testnet") network: \(network)")
                    self.addCurrencies(for: network)
                    guard let currency = self.currency(forCoreCurrency: network.currency) else {
                        print("[SYS] \(network) wallet manager not created. \(network.currency.uids) not supported.")
                        return
                    }
                    
                    if system.migrateRequired(network: network) {
                        self.migrateLegacyDatabase(network: network)
                    }
                    
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
                    system.createWalletManager(network: network,
                                               mode: mode,
                                               addressScheme: addressScheme)
                }

            case .managerAdded(let manager):
                if self.isWalletManagerNeeded(manager) {
                    manager.connect()
                }
            }
        }
    }

    func handleManagerEvent(system: System, manager: BRCrypto.WalletManager, event: WalletManagerEvent) {
        queue.async {
            print("[SYS] \(manager.network) manager event: \(event)")
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
                    manager.network.currencies.compactMap { self.currencies[$0] }.forEach {
                        Store.perform(action: WalletChange($0).setSyncingState(.syncing))
                    }
                }

            case .syncProgress(let timestamp, let percentComplete):
                DispatchQueue.main.async {
                    manager.network.currencies.compactMap { self.currencies[$0] }.forEach {
                        let seconds = UInt32(timestamp?.timeIntervalSince1970 ?? 0)
                        Store.perform(action: WalletChange($0).setProgress(progress: percentComplete, timestamp: seconds))
                    }
                }

            case .syncEnded(let error):
                if let error = error {
                    print("[SYS] \(manager.network) sync error: \(error)")
                }
                DispatchQueue.main.async {
                    manager.network.currencies.compactMap { self.currencies[$0] }.forEach {
                        Store.perform(action: WalletChange($0).setSyncingState(error == nil ? .success : .connecting))
                    }
                }

            case .blockUpdated: // (let height):
                break
            }
        }
    }

    func handleWalletEvent(system: System, manager: BRCrypto.WalletManager, wallet: BRCrypto.Wallet, event: WalletEvent) {
        queue.async {
            print("[SYS] \(manager.network) wallet event: \(wallet.currency.code) \(event)")
            switch event {
            case .created:
                self.addWallet(wallet)
                // generate wallet ID from Ethereum address
                if wallet.currency.uids == Currencies.eth.uid,
                    let walletID = self.walletID(address: wallet.target.description) {
                    DispatchQueue.main.async {
                        Store.perform(action: WalletID.Set(walletID))
                    }
                }

            case .deleted:
                self.removeWallet(wallet)

            default:
                self.wallets[wallet.currency]?.handleWalletEvent(event)
            }
        }
    }

    func handleTransferEvent(system: System, manager: BRCrypto.WalletManager, wallet: BRCrypto.Wallet, transfer: Transfer, event: TransferEvent) {
        queue.async {
            guard let wallet = self.wallets[wallet.currency] else { return }
            print("[SYS] \(manager.network) \(wallet.currency.code) transfer \(transfer.hash?.description.truncateMiddle() ?? "") event: \(event)")
            wallet.handleTransferEvent(event, transfer: transfer)
        }
    }

    func handleNetworkEvent(system: System, network: Network, event: NetworkEvent) {
        queue.async {
            print("[SYS] \(network) network event: \(event)")
        }
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
        case .syncEnded(let error):
            return "syncEnded(\(error ?? ""))"
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
