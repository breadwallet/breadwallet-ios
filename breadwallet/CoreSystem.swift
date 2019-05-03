//
//  CoreSystem.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2019-04-16.
//  Copyright © 2019 breadwallet LLC. All rights reserved.
//

import Foundation
import BRCrypto

class CoreSystem: Subscriber {

    enum State {
        case uninitialized
        case idle
        case active
    }

    private var system: System?
    private let backend = BlockChainDB()
    private (set) var state: State = .uninitialized //TODO:CRYPTO is this needed, if so should it come from System?

    private let queue = DispatchQueue(label: "com.brd.CoreSystem")

    // MARK: Wallets + Currencies

    private var managers = [Network: WalletManagerWrapper]()
    fileprivate var walletControllers = [BRCrypto.Currency: WalletController]()

    // Currency view models indexed by Core Currency
    fileprivate var currencies = [BRCrypto.Currency: Currency]()

    // assume meta data is only additive -- delisted coins are marked unsupported but not removed
    private var currencyMetaData = [String: CurrencyMetaData]()

    func walletController(for currency: Currency) -> WalletController? {
        return walletControllers[currency.core]
    }

    private func addCurrencies(for network: Network) {
        for coreCurrency in network.currencies {
            guard let metaData = currencyMetaData[coreCurrency.code.lowercased()] else {
                assertionFailure("no metadata for currency \(coreCurrency.code)")
                continue
            }
            guard let units = network.unitsFor(currency: coreCurrency),
                let baseUnit = network.baseUnitFor(currency: coreCurrency),
                let defaultUnit = network.defaultUnitFor(currency: coreCurrency),
                let currency = Currency(core: coreCurrency,
                                         metaData: metaData,
                                         units: units,
                                         baseUnit: baseUnit,
                                         defaultUnit: defaultUnit) else {
                                            assertionFailure("unable to create view model for \(coreCurrency.code)")
                                            continue
            }
            print("[CRYPTO] \(network) network currency added: \(currency.code)")
            currencies[coreCurrency] = currency
        }
        DispatchQueue.main.async {
            Store.perform(action: ManageWallets.SetAvailableTokens(Array(self.currencies.values)))
        }
    }

    // MARK: Lifecycle

    // create -- on launch w/ acount present and wallet unlocked
    func create(account: Account) {
        queue.async {
            assert(self.system == nil)
            self.system = SystemBase.create(listener: self,
                                            account: account,
                                            path: C.coreDataDirURL.path,
                                            query: self.backend)
            self.state = .idle
        }
    }

    // connect/start -- foreground / reachable
    func connect() {
        queue.async {
            guard let system = self.system else { return assertionFailure() }
            self.updateCurrencyMetaData {
                //TODO:CRYPTO where should this list come from?
                system.start(networksNeeded: ["bitcoin-mainnet", "ethereum-mainnet"])
                self.state = .active
            }
        }
    }

    // disconnect/stop -- background / unreachable
    func disconnect() {
        queue.async {
            guard let system = self.system else { return assertionFailure() }
            system.stop()
            self.state = .idle
        }
    }

    // shutdown -- wallet unlinked / account removed
    func shutdown() {
        queue.async {
            guard self.system != nil else { return assertionFailure() }
            self.system!.stop()
            //TODO:CRYPTO remove account / wipe persistent store
            self.managers.removeAll()
            self.walletControllers.removeAll()
            self.currencies.removeAll()
            self.system = nil
            self.state = .uninitialized
        }
    }

    //TODO:CRYPTO migrate legacy persistent data

    // MARK: Wallet Management

    private func addWalletController(_ wallet: Wallet, manager: BRCrypto.WalletManager) {
        guard walletControllers[wallet.currency] == nil else { return assertionFailure() }
        guard let currency = currencies[wallet.currency],
        let manager = managers[manager.network] else { return assertionFailure() }
        let walletController = WalletController(wallet: wallet, currency: currency, manager: manager)
        walletControllers[wallet.currency] = walletController

        //TODO:CRYPTO need to filter System wallets with list of user-selected wallets
        // hack to add wallet to home screen
        let newWallet = WalletState.initial(currency, wallet: walletController, displayOrder: 0)
        DispatchQueue.main.async {
            Store.perform(action: ManageWallets.AddWallets([currency.code: newWallet]))
        }
    }

    private func removeWalletController(_ wallet: Wallet) {
        //TODO:CRYPTO when does this happen? can it happen without user intervention?
        guard self.walletControllers[wallet.currency] != nil else { return assertionFailure() }
        self.walletControllers[wallet.currency] = nil
    }

    // MARK: Currency Management

    private func updateCurrencyMetaData(completion: (() -> Void)? = nil) {
        let process: ([CurrencyMetaData]) -> Void = { tokens in
            self.currencyMetaData = tokens.reduce(into: [String: CurrencyMetaData](), { (dict, token) in
                dict[token.code.lowercased()] = token
            })
            print("[TokenList] tokens updated: \(tokens.count) tokens")
            completion?()
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
        Backend.apiClient.getCurrencyMetaData { result in
            self.queue.async {
                switch result {
                case .success(let tokens):
                    // update cache
                    do {
                        let data = try JSONEncoder().encode(tokens)
                        try data.write(to: URL(fileURLWithPath: cachedFilePath))
                    } catch let e {
                        print("[TokenList] failed to write to cache: \(e.localizedDescription)")
                    }
                    process(tokens)

                case .error(let error):
                    print("[TokenList] error fetching tokens: \(error)")
                    var tokens = [CurrencyMetaData]()
                    do {
                        print("[TokenList] using cached token list")
                        let cachedData = try Data(contentsOf: URL(fileURLWithPath: cachedFilePath))
                        tokens = try JSONDecoder().decode([CurrencyMetaData].self, from: cachedData)
                    } catch let e {
                        print("[TokenList] error reading from cache: \(e)")
                        fatalError("unable to read token list!")
                    }
                    process(tokens)
                }
            }
        }
    }
}

extension CoreSystem: SystemListener {

    func handleSystemEvent(system: System, event: SystemEvent) {
        queue.async {
            print("[CRYPTO] system event: \(event)")
            switch event {
            case .created:
                DispatchQueue.main.async {
                    //TODO:CRYPTO hack to clear all wallets and show only the System wallets
                    Store.perform(action: ManageWallets.SetWallets([:]))
                }

            case .networkAdded(let network):
                // A network was created; create the corresponding wallet manager.
                if network.isMainnet == !E.isTestnet {
                    self.addCurrencies(for: network)
                    let mode = (network.currency.code == BRCrypto.Currency.codeAsBTC ||
                        network.currency.code == BRCrypto.Currency.codeAsBCH
                        ? WalletManagerMode.api_only
                        : WalletManagerMode.api_only)
                    system.createWalletManager(network: network,
                                               mode: mode)
                }

            case .managerAdded(let manager):
                assert(self.managers[manager.network] == nil)
                self.managers[manager.network] = WalletManagerWrapper(core: manager, system: self)
                manager.connect()
            }
        }
    }

    func handleManagerEvent(system: System, manager: BRCrypto.WalletManager, event: WalletManagerEvent) {
        print("[CRYPTO] manager event: \(manager.network) \(event)")
        queue.async {
            guard let walletManager = self.managers[manager.network] else {
                if case .created = event {
                    // ignore
                } else {
                    assertionFailure()
                }
                return
            }

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
                    walletManager.currencies.forEach {
                        Store.perform(action: WalletChange($0).setSyncingState(.syncing))
                    }
                }

            case .syncProgress(let percentComplete):
                DispatchQueue.main.async {
                    walletManager.currencies.forEach {
                        Store.perform(action: WalletChange($0).setProgress(progress: percentComplete, timestamp: 0))
                    }
                }

            case .syncEnded(let error):
                if let error = error {
                    print("[CRYPTO] \(manager.network) sync error: \(error)")
                }
                DispatchQueue.main.async {
                    walletManager.currencies.forEach {
                        Store.perform(action: WalletChange($0).setSyncingState(error == nil ? .success : .connecting))
                    }
                }

            case .blockUpdated: // (let height):
                break
            }
        }
    }

    func handleWalletEvent(system: System, manager: BRCrypto.WalletManager, wallet: Wallet, event: WalletEvent) {
        queue.async {
            print("[CRYPTO] \(manager.network) wallet event: \(wallet.currency.code) \(event)")
            switch event {
            case .created:
                self.addWalletController(wallet, manager: manager)

            case .deleted:
                self.removeWalletController(wallet)

            default:
                guard let walletController = self.walletControllers[wallet.currency] else { return assertionFailure() }
                walletController.handleWalletEvent(system: system,
                                                   manager: manager,
                                                   wallet: wallet,
                                                   event: event)
            }
        }
    }

    func handleTransferEvent(system: System, manager: BRCrypto.WalletManager, wallet: Wallet, transfer: Transfer, event: TransferEvent) {
        queue.async {
            print("[CRYPTO] \(manager.network) \(wallet.currency.code) transfer \(transfer.hash?.description.truncateMiddle() ?? "") event: \(event)")
            guard let walletController = self.walletControllers[wallet.currency] else { return assertionFailure() }
            walletController.handleTransferEvent(system: system,
                                                 manager: manager,
                                                 wallet: wallet,
                                                 transfer: transfer,
                                                 event: event)
        }
    }

    func handleNetworkEvent(system: System, network: Network, event: NetworkEvent) {
        queue.async {
            print("[CRYPTO] network event: \(network) \(event)")
        }
    }
}

//TODO:CRYPTO rename this to WalletManager after removing the old protocol
class WalletManagerWrapper {
    private let core: BRCrypto.WalletManager
    unowned var system: CoreSystem

    var primaryCurrency: Currency {
        return system.currencies[core.primaryWallet.currency]!
    }

    var currencies: [Currency] {
        return core.wallets.map { $0.currency }.compactMap { system.currencies[$0] }
    }

    var wallets: [WalletController] {
        return core.wallets.compactMap { system.walletControllers[$0.currency] }
    }

    var primaryWallet: WalletController {
        return system.walletControllers[primaryCurrency.core]!
    }

    func currency(from core: BRCrypto.Currency) -> Currency? {
        return system.currencies[core]
    }

    var blockHeight: UInt64? {
        return core.network.height
    }

    init(core: BRCrypto.WalletManager, system: CoreSystem) {
        self.core = core
        self.system = system
    }
}

extension Network: Hashable {
    public static func == (lhs: Network, rhs: Network) -> Bool {
        return lhs.uids == rhs.uids
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(uids)
        hasher.combine(name)
    }
}
