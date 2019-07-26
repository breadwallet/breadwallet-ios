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

    enum State {
        case uninitialized
        case idle
        case active
    }

    private var supportedNetworks: [String] {
        let variant = E.isTestnet ? "testnet" : "mainnet"
        return ["bitcoin", "ethereum"].map { "\($0)-\(variant)" }
    }

    private var system: System?
    private let backend = BlockChainDB()
    private (set) var state: State = .uninitialized //TODO:CRYPTO is this needed, if so should it come from System?
    private var isInitialized: Bool { return state != .uninitialized }

    private let queue = DispatchQueue(label: "com.brd.CoreSystem")

    // MARK: Wallets + Currencies

    fileprivate var wallets = [BRCrypto.Currency: Wallet]()

    // Currency view models indexed by Core Currency
    fileprivate var currencies = [BRCrypto.Currency: Currency]()

    func currency(forCoreCurrency core: BRCrypto.Currency) -> Currency? {
        return currencies[core]
    }

    // assume meta data is only additive -- delisted coins are marked unsupported but not removed
    private var currencyMetaData = [String: CurrencyMetaData]()

    func wallet(for currency: Currency) -> Wallet? {
        return wallets[currency.core]
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
            print("[SYS] currency added: \(network) \(currency.code)")
            currencies[coreCurrency] = currency
            if coreCurrency == network.currency {
                //TODO:CRYPTO fee updater to be replaced
                Backend.setupFeeUpdater(for: currency)
            }
        }
        DispatchQueue.main.async {
            Store.perform(action: ManageWallets.SetAvailableTokens(Array(self.currencies.values)))
        }
    }

    // MARK: Lifecycle

    // create -- on launch w/ acount present and wallet unlocked
    func create(account: Account) {
        assert(state == .uninitialized)
        print("[SYS] create")
        queue.async {
            assert(self.system == nil)
            self.system = System(listener: self,
                                 account: account,
                                 path: C.coreDataDirURL.path,
                                 query: self.backend)
            self.updateCurrencyMetaData {
                self.system?.configure()
            }
            self.state = .idle
        }
    }

    // connect/start -- foreground / reachable
    func connect() {
        print("[SYS] connect")
        queue.async {
            guard let system = self.system else { return assertionFailure() }
            system.managers.forEach { $0.connect() }
            self.state = .active
        }
    }

    // disconnect/stop -- background / unreachable
    func disconnect() {
        print("[SYS] disconnect")
        queue.async {
            guard let system = self.system else { return assertionFailure() }
            system.stop()
            self.state = .idle
        }
    }

    // shutdown -- wallet unlinked / account removed
    func shutdown(completion: (() -> Void)?) {
        print("[SYS] shutdown / wipe")
        queue.sync {
            guard let system = self.system else { return assertionFailure() }
            self.state = .uninitialized
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

    //TODO:CRYPTO migrate legacy persistent data

    // MARK: Wallet Management

    private func addWallet(_ coreWallet: BRCrypto.Wallet, manager: BRCrypto.WalletManager) {
        guard wallets[coreWallet.currency] == nil,
            let currency = currencies[coreWallet.currency] else { return assertionFailure() }
        let wallet = Wallet(core: coreWallet, currency: currency, system: self)
        wallets[coreWallet.currency] = wallet

        //TODO:CRYPTO need to filter System wallets with list of user-selected wallets
        // hack to add wallet to home screen
        let walletState = WalletState.initial(currency, wallet: wallet, displayOrder: 0)
        DispatchQueue.main.async {
            Store.perform(action: ManageWallets.AddWallets([currency.code: walletState]))

            //TODO:CRYPTO optimize to avoid making a new exchange rate request for each wallet added on launch
            Backend.updateExchangeRates()
        }
    }

    private func removeWallet(_ coreWallet: BRCrypto.Wallet) {
        //TODO:CRYPTO when does this happen? can it happen without user intervention?
        guard self.wallets[coreWallet.currency] != nil else { return assertionFailure() }
        self.wallets[coreWallet.currency] = nil
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
        guard isInitialized else { return }
        queue.async {
            print("[SYS] system event: \(event)")
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
                    system.createWalletManager(network: network,
                                               mode: network.defaultManagerMode,
                                               addressScheme: system.defaultAddressScheme(network: network))
                }

            case .managerAdded(let manager):
                manager.connect()
            }
        }
    }

    func handleManagerEvent(system: System, manager: BRCrypto.WalletManager, event: WalletManagerEvent) {
        guard isInitialized else { return }
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

            case .syncProgress(let percentComplete):
                DispatchQueue.main.async {
                    manager.network.currencies.compactMap { self.currencies[$0] }.forEach {
                        Store.perform(action: WalletChange($0).setProgress(progress: percentComplete, timestamp: 0))
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
        guard isInitialized else { return }
        queue.async {
            print("[SYS] \(manager.network) wallet event: \(wallet.currency.code) \(event)")
            switch event {
            case .created:
                self.addWallet(wallet, manager: manager)

            case .deleted:
                self.removeWallet(wallet)

            default:
                guard let wallet = self.wallets[wallet.currency] else { return assertionFailure() }
                wallet.handleWalletEvent(event)
            }
        }
    }

    func handleTransferEvent(system: System, manager: BRCrypto.WalletManager, wallet: BRCrypto.Wallet, transfer: Transfer, event: TransferEvent) {
        guard isInitialized else { return }
        queue.async {
            print("[SYS] \(manager.network) \(wallet.currency.code) transfer \(transfer.hash?.description.truncateMiddle() ?? "") event: \(event)")
            guard let wallet = self.wallets[wallet.currency] else { return assertionFailure() }
            wallet.handleTransferEvent(event, transfer: transfer)
        }
    }

    func handleNetworkEvent(system: System, network: Network, event: NetworkEvent) {
        guard isInitialized else { return }
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

extension BRCrypto.Network {
    var defaultManagerMode: WalletManagerMode {
        switch currency.code {
        case BRCrypto.Currency.codeAsBTC:
            return .api_only
        case BRCrypto.Currency.codeAsBCH:
            return .p2p_only
        case BRCrypto.Currency.codeAsETH:
            return .api_only
        default:
            return .api_only
        }
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
