//
//  BREthereum.swift
//  breadwallet
//
//  Created by Ed Gamble on 3/28/18.
//  Copyright © 2018 breadwallet LLC. All rights reserved.
//

import Foundation
import BRCore.Ethereum

// swiftlint:disable cyclomatic_complexity
// swiftlint:disable function_parameter_count
// swiftlint:disable type_body_length

public typealias EthereumReferenceId = OpaquePointer?
public typealias EthereumWalletId = EthereumReferenceId
public typealias EthereumTransferId = EthereumReferenceId
public typealias EthereumAccountId = EthereumReferenceId
public typealias EthereumAddressId = EthereumReferenceId
public typealias EthereumBlockId = EthereumReferenceId

public typealias EthereumTransactionId = EthereumTransferId
public typealias EthereumTransaction = EthereumTransfer

// MARK: Reference

///
/// Core Ethereum *does not* allow direct access to Core 'C' Memory; instead we use references
/// within an `EthereumEWM`.  This allows the Core to avoid multiprocessing issues arising
/// from Client access in arbitrary threads.  Additionally, the Core is free to manage its own
/// memory w/o regard to a Client holding a reference (that the Core can never, even know about).
///
/// Attemping to access a Core reference that no longer exists in the Core results in an error.
/// But how so is TBD.
///
/// An EthereumReference is Equatable based on the `EthereumEWM` and the identifier (of the
/// reference).  Generally adopters of `EthereumReference` will be structures as all their
/// properties are computed via a C function on `EthereumEWM`.
///
protocol EthereumReference: Equatable {
    associatedtype ReferenceType: Equatable

    var ewm: EthereumWalletManager? { get }

    var identifier: ReferenceType { get }
}

extension EthereumReference {
    static public func == (lhs: Self, rhs: Self) -> Bool {
        return rhs.ewm === lhs.ewm && rhs.identifier == lhs.identifier
    }
}

// MARK: - Pointer

///
/// An `EthereumPointer` holds an `OpaquePointer` to Ethereum Core memory.  This is used for
/// 'constant-like' memory references.
///
private protocol EthereumPointer: Equatable {
    associatedtype PointerType: Equatable

    var core: PointerType { get }
}

extension EthereumPointer {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.core == rhs.core
    }
}

// MARK: - Network

///
/// An `EthereumNetwork` represents one of a handful of Ethereum (Blockchain) Networks such as:
/// mainnet, testnet/ropsten, rinkeby
///
enum EthereumNetwork: EthereumPointer {
    case mainnet
    case testnet // ropsten
    case rinkeby
    
    var core: BREthereumNetwork {
        switch self {
        case .mainnet: return ethereumMainnet
        case .testnet: return ethereumTestnet
        case .rinkeby: return ethereumRinkeby
        }
    }
    
    var chainId: Int {
        return Int(exactly: networkGetChainId (core))!
    }
}

// MARK: - Token

extension ERC20Token {
    var core: BREthereumToken? {
        return tokenLookup(self.address)
    }
}

extension ERC20Token: Equatable {
    public static func == (lhs: ERC20Token, rhs: ERC20Token) -> Bool {
        return (lhs.code.compare(rhs.code, options: .caseInsensitive) == .orderedSame) &&
            (lhs.address.compare(rhs.address, options: .caseInsensitive) == .orderedSame)
    }
}

// MARK: - Wallet

///
/// An `EthereumWallet` holds a balance and transactions of ETHER or a TOKEN
///
struct EthereumWallet: EthereumReference {
    weak var ewm: EthereumWalletManager?
    let identifier: EthereumWalletId
    let currency: Currency
    
    //
    // MARK: Gas Limit
    //
    var defaultGasLimit: UInt64 {
        get {
            return ewmWalletGetDefaultGasLimit (ewm!.core, identifier).amountOfGas
        }
        set (value) {
            ewmWalletSetDefaultGasLimit (ewm!.core, identifier, gasCreate(value))
        }
    }
    
    func gasEstimate (transaction: EthereumTransfer) -> UInt64 {
        return ewmWalletGetGasEstimate (self.ewm!.core, self.identifier, transaction.identifier).amountOfGas
    }
    
    //
    // MARK: Gas Price
    //
    static let maximumGasPrice: UInt64 = 100000000000000
    
    var defaultGasPrice: UInt64 {
        return ewmWalletGetDefaultGasPrice (self.ewm!.core, self.identifier).etherPerGas.valueInWEI.u64.0
    }
    
    func setDefaultGasPrice(_ value: UInt64) {
        precondition(value <= EthereumWallet.maximumGasPrice)
        ewmWalletSetDefaultGasPrice (self.ewm!.core, self.identifier,
                                     gasPriceCreate(etherCreateNumber(value, WEI)))
    }
    
    //
    // MARK: Balance
    //
    var balance: UInt256 {
        let amount: BREthereumAmount = ewmWalletGetBalance(ewm!.core, identifier)
        return (AMOUNT_ETHER == amount.type)
            ? amount.u.ether.valueInWEI
            : amount.u.tokenQuantity.valueAsInteger
    }
    
    //
    // MARK: Constructor
    //
    internal init (ewm: EthereumWalletManager,
                   wid: EthereumWalletId,
                   currency: Currency) {
        self.ewm = ewm
        self.identifier = wid
        self.currency = currency
    }
    
    //
    // MARK: Transaction
    //
    func createTransaction (currency: Currency, recvAddress: String, amount: UInt256) -> EthereumTransfer {
        var coreAmount: BREthereumAmount
        if let token = currency as? ERC20Token {
            coreAmount = amountCreateToken(createTokenQuantity(token.core!, amount))
        } else {
            coreAmount = amountCreateEther(etherCreate(amount))
        }

        let tid = ewmWalletCreateTransfer (ewm!.core,
                                           identifier,
                                           recvAddress,
                                           coreAmount)
        return EthereumTransfer (ewm: ewm!, currency: currency, identifier: tid)
    }
    
    /// Create a contract execution transaction. Amount is ETH (in wei) and data is the ABI payload (hex-encoded string)
    /// Optionally specify gasPrice and gasLimit to use, otherwise defaults will be used.
    func createContractTransaction (recvAddress: String, amount: UInt256, data: String, gasPrice: UInt256? = nil, gasLimit: UInt64? = nil) -> EthereumTransfer {
        let coreAmount = etherCreate(amount)
        let gasPrice = gasPrice ?? UInt256(defaultGasPrice)
        let gasLimit = gasLimit ?? defaultGasLimit
        
        let tid = ewmWalletCreateTransferGeneric (ewm!.core,
                                                  identifier,
                                                  recvAddress,
                                                  coreAmount,
                                                  gasPriceCreate(etherCreate(gasPrice)),
                                                  gasCreate(gasLimit),
                                                  data)
        return EthereumTransfer (ewm: ewm!, currency: currency, identifier: tid)
    }
    
    func sign (transaction: EthereumTransfer, privateKey: BRKey) {
        ewmWalletSignTransfer (self.ewm!.core, self.identifier, transaction.identifier, privateKey)
    }
    
    func rawTransactionHexEncoded(_ transaction: EthereumTransfer) -> String? {
        guard let hex = ewmTransferGetRawDataHexEncoded (self.ewm!.core, self.identifier, transaction.identifier, "0x") else { return nil }
        return asUTF8String (hex)
    }

    func updateGasEstimate(for transaction: EthereumTransfer) {
        ewmUpdateGasEstimate(ewm!.core, identifier, transaction.identifier)
    }
    
    /// Triggers submitTransaction callback on EthereumClient (BRD_ONLY) or submits transactions via P2P network
    func submit (transaction: EthereumTransfer) {
        ewmWalletSubmitTransfer (self.ewm!.core, self.identifier, transaction.identifier)
    }
    
    var transactions: [EthereumTransfer] {
        let count = ewmWalletGetTransferCount (self.ewm!.core, self.identifier)
        let identifiers = ewmWalletGetTransfers (self.ewm!.core, self.identifier)
        defer { free(identifiers) }
        return UnsafeBufferPointer (start: identifiers, count: Int(exactly: count)!)
            .map { self.ewm!.findTransaction(currency: self.currency, identifier: $0) }
    }
    
    var transactionsCount: Int {
        return Int (exactly: ewmWalletGetTransferCount (self.ewm!.core, self.identifier))!
    }
    
    //
    // MARK: Update
    //
    
    func updateDefaultGasPrice() {
        ewmUpdateGasPrice (ewm!.core, identifier)
    }
}

// MARK: - Transaction

///
/// An `EthereumTransaction` represents a transfer of ETHER or a specific TOKEN between two
/// accounts.
///
public struct EthereumTransfer: EthereumReference {
    weak var ewm: EthereumWalletManager?
    let identifier: EthereumTransactionId
    let currency: Currency

    internal init (ewm: EthereumWalletManager, currency: Currency, identifier: EthereumTransactionId) {
        self.ewm = ewm
        self.identifier = identifier
        self.currency = currency
    }

    var hash: String {
        // token transfers are associated with one or more log events and the originating Ethereum transaction.
        // Core requires a unique hash for each transfer, so it uses a combination of the originating transaction hash
        // and the index of the log event in the block as the transfer's hash.
        // the app only requires the originating transaction hash.
        let hash = ewmTransferGetOriginatingTransactionHash(self.ewm!.core, self.identifier)
        return asUTF8String (hashAsString(hash), true)
    }

    var sourceAddress: String {
        return asUTF8String (addressGetEncodedString(ewmTransferGetSource(self.ewm!.core, self.identifier), 1), true)
    }

    var targetAddress: String {
        return asUTF8String (addressGetEncodedString(ewmTransferGetTarget(self.ewm!.core, self.identifier), 1), true)
    }

    var amount: UInt256 {
        let amount: BREthereumAmount = ewmTransferGetAmount(self.ewm!.core, self.identifier)
        return (AMOUNT_ETHER == amount.type)
            ? amount.u.ether.valueInWEI
            : amount.u.tokenQuantity.valueAsInteger
    }

    var gasPrice: UInt256 {
        return ewmTransferGetGasPrice(self.ewm!.core, self.identifier, WEI).etherPerGas.valueInWEI
    }

    var gasLimit: UInt64 {
        return ewmTransferGetGasLimit(self.ewm!.core, self.identifier).amountOfGas
    }

    var gasUsed: UInt64 {
        return ewmTransferGetGasUsed(self.ewm!.core, self.identifier).amountOfGas
    }

    var nonce: UInt64 {
        return ewmTransferGetNonce(self.ewm!.core, self.identifier)
    }

    var blockNumber: UInt64 {
        return ewmTransferGetBlockNumber (self.ewm!.core, self.identifier)
    }

    var blockTimestamp: UInt64 {
        return ewmTransferGetBlockTimestamp (self.ewm!.core, self.identifier)
    }

    var confirmations: UInt64 {
        return ewmTransferGetBlockConfirmations(self.ewm!.core, self.identifier)
    }

    var errorStatus: EthereumTransferError {
        let code = Int(ewmTransferStatusGetErrorType(self.ewm!.core, self.identifier))
        var message = ""
        if let errorMessage = ewmTransferStatusGetError(self.ewm!.core, self.identifier) {
            message = asUTF8String(errorMessage)
        }
        return EthereumTransferError(code: code, message: message)
    }
}

public struct EthereumTransferError: Error {
    let code: Int
    let message: String

    var isError: Bool { return code != -1 }
}

// MARK: - Client

public enum EthereumMode: Int, CustomStringConvertible, CaseIterable {
    case brd_only
    case brd_with_p2p_send
    case p2p_with_brd_sync
    case p2p_only

    init (_ mode: BREthereumMode) {
        switch mode {
        case BRD_ONLY: self = .brd_only
        case BRD_WITH_P2P_SEND: self = .brd_with_p2p_send
        case P2P_WITH_BRD_SYNC: self = .p2p_with_brd_sync
        case P2P_ONLY: self = .p2p_only
        default:
            self = .p2p_only
        }
    }

    var core: BREthereumMode {
        switch self {
        case .brd_only: return BRD_ONLY
        case .brd_with_p2p_send: return BRD_WITH_P2P_SEND
        case .p2p_with_brd_sync: return P2P_WITH_BRD_SYNC
        case .p2p_only: return P2P_ONLY
        }
    }
    
    public var description: String {
        switch self {
        case .brd_only: return "API only"
        case .brd_with_p2p_send: return "API sync / P2P send"
        case .p2p_with_brd_sync: return "P2P+API sync / P2P send"
        case .p2p_only: return "P2P only"
        }
    }
}

public enum EthereumWalletEvent: Int {
    case created
    case balanceUpdated
    case defaultGasLimitUpdated
    case defaultGasPriceUpdated
    case deleted

    init (_ event: BREthereumWalletEvent) {
        self.init (rawValue: Int (event.rawValue))!
    }
}

public enum EthereumBlockEvent: Int {
    case created
    case chained
    case orphaned
    case deleted
    init (_ event: BREthereumBlockEvent) {
        self.init (rawValue: Int (event.rawValue))!
    }
}

public enum EthereumTransferEvent: Int {
    case created
    case signed
    case submitted
    case included
    case errored

    case gasEstimateUpdated
    case blockConfirmationsUpdated

    case deleted

    init (_ event: BREthereumTransferEvent) {
        self.init (rawValue: Int (event.rawValue))!
    }
}

public enum EthereumPeerEvent: Int {
    case created
    case deleted

    init (_ event: BREthereumPeerEvent) {
        self.init(rawValue: Int(event.rawValue))!
    }
}

public enum EthereumTokenEvent: Int {
    case created
    case deleted

    init (_ event: BREthereumTokenEvent) {
        self.init (rawValue: Int(event.rawValue))!
    }
}

public enum EthereumEWMEvent: Int {
    case created
    case sync_started
    case sync_continues
    case sync_stopped
    case network_unavailable
    case deleted

    init (_ event: BREthereumEWMEvent) {
        switch event {
        case EWM_EVENT_CREATED: self = .created
        case EWM_EVENT_SYNC_STARTED: self = .sync_started
        case EWM_EVENT_SYNC_CONTINUES: self = .sync_continues
        case EWM_EVENT_SYNC_STOPPED: self = .sync_stopped
        case EWM_EVENT_NETWORK_UNAVAILABLE: self = .network_unavailable
        case EWM_EVENT_DELETED: self = .deleted
        default:
            assert(false, "Uknown BREthereumEWMEvent: \(event)")
            self = .deleted
        }
    }
}

///
/// An `EthereumClient` is a protocol defined with a set of functions that support an
/// EthereumLightNode.
///
protocol EthereumClient: class {
    typealias AmountHandler = (String) -> Void
    typealias SubmitTransactionHandler = (JSONRPCResult<String>) -> Void
    typealias TransactionsHandler = (APIResult<[EthTxJSON]>) -> Void
    typealias LogsHandler = (APIResult<[EthLogEventJSON]>) -> Void
    
    func getGasPrice (wallet: EthereumWallet, completion: @escaping AmountHandler)
    func getGasEstimate (wallet: EthereumWallet,
                         tid: EthereumTransactionId,
                         from: String,
                         to: String,
                         amount: String,
                         data: String,
                         completion: @escaping AmountHandler)
    
    func getBalance (wallet: EthereumWallet, address: String, completion: @escaping AmountHandler)
    
    func submitTransaction (wallet: EthereumWallet,
                            tid: EthereumTransactionId,
                            rawTransaction: String,
                            completion: @escaping SubmitTransactionHandler)

    func getTransactions (address: String, blockStart: UInt64, blockStop: UInt64, completion: @escaping TransactionsHandler)
    
    func getLogs (address: String, event: String, blockStart: UInt64, blockStop: UInt64, completion: @escaping LogsHandler)

    func getBlocks (ewm: EthereumWalletManager,
                    address: String,
                    interests: UInt32,
                    blockStart: UInt64,
                    blockStop: UInt64,
                    rid: Int32)

    func getTokens (ewm: EthereumWalletManager,
                    rid: Int32)
    
    func getBlockNumber(completion: @escaping AmountHandler)
    
    func getNonce(address: String, completion: @escaping AmountHandler)

    // Listener
    func handleEWMEvent (ewm: EthereumWalletManager,
                         event: EthereumEWMEvent)

    func handlePeerEvent (ewm: EthereumWalletManager,
                          event: EthereumPeerEvent)

    func handleWalletEvent (ewm: EthereumWalletManager,
                            wallet: EthereumWallet,
                            event: EthereumWalletEvent)

    func handleTokenEvent (ewm: EthereumWalletManager,
                           token: ERC20Token,
                           event: EthereumTokenEvent)

    func handleTransferEvent (ewm: EthereumWalletManager,
                              wallet: EthereumWallet,
                              transfer: EthereumTransfer,
                              event: EthereumTransferEvent)
}

public enum EthereumKey {
    case paperKey (String)
    case publicKey (BRKey)
}

// MARK: - LightNode

///
/// An `EthereumLightNode` is a SPV/LES (Simplified Payment Verification / Light Ethereum
/// Subprotocol) node in an Ethereum Network.
///
class EthereumWalletManager: EthereumPointer {
    
    ///
    /// The OpaquePointer to the 'Core Ethereum LightNode'.  We defer nearly all functions
    /// to this reference.
    ///
    let core: BREthereumEWM
    
    ///
    /// The client ...
    ///
    weak private(set) var client: EthereumClient?
    
    ///
    /// The network ...
    ///
    let network: EthereumNetwork
    
    lazy var address: String = {
        let cString = ewmGetAccountPrimaryAddress (core)
        let string = String (cString: cString!)
        free (cString)
        return string
    }()
    
    public init (client: EthereumClient,
                 network: EthereumNetwork,
                 mode: EthereumMode,
                 key: EthereumKey,
                 timestamp: UInt64,
                 storagePath: String) {
        var core: BREthereumEWM

        switch key {
        case .paperKey:
            fatalError("do not use")

        case let .publicKey(key):
            core = ewmCreateWithPublicKey (network.core,
                                           key,
                                           timestamp,
                                           mode.core,
                                           EthereumWalletManager.createCoreClient(client: client),
                                           storagePath)
        }

        self.core = core
        self.client = client
        self.network = network
        EthereumWalletManager.add(self)
    }

    // MARK: Queues

    /// Serial queue for Core operations
    private let serialQueue = DispatchQueue(label: "com.brd.ewm.serial")
    /// Concurrent queue for EWM data operations
    private let concurrentQueue = DispatchQueue(label: "com.brd.ewm.concurrent", attributes: .concurrent)

    /// Execute on EWM serial queue (asynchronous/serial)
    /// - Use for executing core functions or accessing core data structures
    func serialAsync(thunk: @escaping () -> Void) {
        serialQueue.async {
            thunk()
        }
    }

    /// Execute on EWM concurrent data queue (asynchronous/barrier)
    /// - Use for thread-safe write of EWM properties
    /// - Avoid calling serialAsync or readSync inside a write operation
    func writeAsync(thunk: @escaping () -> Void) {
        concurrentQueue.async(flags: .barrier) {
            thunk()
        }
    }

    /// Execute on concurrent EWM data queue (synchronous/concurrent) and return a value
    /// - Use for thread-safe read of EWM properties
    func readSync<T>(thunk: @escaping () -> T) -> T {
        return concurrentQueue.sync {
            return thunk()
        }
    }

    //
    // MARK: Tokens
    //

    /// All available ERC20 tokens by contract address
    /// - always use thread-safe accessors (readSync / writeAsync / readWriteSync)
    private var allTokensByAddress: [String: ERC20Token] = [:]

    func setAvailableTokens(_ tokens: [ERC20Token]) {
        writeAsync {
            self.allTokensByAddress = tokens.reduce(into: [String: ERC20Token]()) { dict, token in
                dict[token.address] = token
            }
        }
        serialAsync {
            for token in tokens {
                ewmAnnounceToken(self.core,
                                 token.address,
                                 token.symbol,
                                 token.code,
                                 token.name,
                                 UInt32(token.decimals),
                                 nil, // gas limit
                                 nil, // gas price
                                 0)
            }
        }
    }

    private func findToken(coreToken: BREthereumToken) -> ERC20Token? {
        let address = asUTF8String(tokenGetAddress(coreToken))
        return readSync { return self.allTokensByAddress[address] }
    }
    
    //
    // MARK: Wallets
    //

    /// Active wallets by currency ticket code
    /// - always use thread-safe accessors (readSync / writeAsync / readWriteSync)
    private var walletsByTicker: [String: EthereumWallet] = [:]

    /// Active wallets by core wallet ID
    /// - always use thread-safe accessors (readSync / writeAsync / readWriteSync)
    private var walletsById: [EthereumWalletId: EthereumWallet] = [:]

    private func findWallet(withIdentifier identifier: EthereumWalletId) -> EthereumWallet? {
        return readSync { return self.walletsById[identifier] }
    }

    /// Looks up the wallet's token in allTokensByAddress
    private func tokenForWallet(withIdentifier wid: BREthereumWallet) -> ERC20Token? {
        guard let coreToken = ewmWalletGetToken(self.core, wid) else { return nil }
        return findToken(coreToken: coreToken)
    }
    
    func wallet(for currency: Currency) -> EthereumWallet? {
        return readSync { return self.walletsByTicker[currency.code] }
    }
    
    func createWallet(for currency: Currency) {
        serialAsync {
            guard self.wallet(for: currency) == nil else { return print("[BRETH] \(currency.code) wallet already exists") } // this can happen in a race condition
            print("[BRETH] creating wallet \(currency.code)")

            var identifier: EthereumWalletId
            if let token = currency as? ERC20Token {
                assert(token.core != nil, "wait for core token to be created before accessing its wallet")
                // this triggeres a WALLET_EVENT_CREATED
                identifier = ewmGetWalletHoldingToken(self.core, token.core!)
            } else {
                identifier = ewmGetWallet(self.core)
            }
            _ = self.handleWalletCreation(wid: identifier, currency: currency)
        }
    }

    /// This adds the token/wallet mapping and may be triggered by `createWallet` or by `WALLET_EVENT_CREATED`
    private func handleWalletCreation(wid: EthereumWalletId, currency: Currency) -> EthereumWallet {
        if let existingWallet = self.wallet(for: currency) {
            print("[BRETH] \(currency.code) wallet already exists")
            return existingWallet
        }
        let wallet = EthereumWallet(ewm: self, wid: wid, currency: currency)
        self.writeAsync {
            self.walletsById[wid] = wallet
            self.walletsByTicker[currency.code] = wallet
            print("[BRETH] created wallet \(currency.code)")
            self.serialAsync {
                ewmUpdateWalletBalance(self.core, wid)
            }
        }
        return wallet
    }
    
    /// Sets default gas price on all wallets
    func updateDefaultGasPrice(_ gasPrice: UInt256) {
        serialAsync {
            let wallets = self.readSync { return self.walletsById.values }
            wallets.forEach { $0.setDefaultGasPrice(gasPrice.asUInt64) }
        }
    }
    
    //
    // Block
    //
    var blockHeight: UInt64 {
        return ewmGetBlockHeight (core)
    }
    
    //
    // Transactions
    //
    internal func findTransaction (currency: Currency, identifier: EthereumTransactionId) -> EthereumTransfer {
        return EthereumTransfer (ewm: self, currency: currency, identifier: identifier)
    }
    
    //
    // Connect / Disconnect
    //
    private var coreClient: BREthereumClient?

    var isConnected: Bool {
        return ewmIsConnected(self.core) == ETHEREUM_BOOLEAN_TRUE
    }
    
    func connect () {
        serialAsync {
            ewmConnect (self.core)
        }
    }
    
    func disconnect () {
        serialAsync {
            ewmDisconnect (self.core)
        }
    }

    /// Initiates a re-sync of the blockchain state
    /// - sets all transactions to pending until state is refetched
    func rescan() {
        serialAsync {
            ewmSync(self.core, ETHEREUM_BOOLEAN_TRUE)
        }
    }
    
    ///
    /// Create an BREthereumEWMConfiguration for a JSON_RPC client.  The configuration
    /// will invoke Client functions for EWM callbacks, implementing, for example,
    /// getTransactions().  In this case, the client is expected to make a JSON_RPC call
    /// returning a list of JSON transactions and then to processing each transaction by
    /// calling announceTransaction().
    ///
    static func createCoreClient(client: EthereumClient) -> BREthereumClient {
        let client = AnyEthereumClient (base: client)
        return BREthereumClient (
            context: UnsafeMutableRawPointer (Unmanaged<AnyEthereumClient>.passRetained(client).toOpaque()),

            // Client Callbacks

            funcGetBalance: { (coreClient, coreEWM, wid, address, rid) in
                guard let client = coreClient.map ({ Unmanaged<AnyEthereumClient>.fromOpaque($0).takeUnretainedValue() }),
                    let ewm = EthereumWalletManager.lookup(core: coreEWM),
                    let wallet = ewm.findWallet(withIdentifier: wid) else { return }
                let address = asUTF8String(address!)
                client.getBalance(wallet: wallet, address: address, completion: { balance in
                    ewm.serialAsync {
                        ewmAnnounceWalletBalance(coreEWM, wid, balance, rid)
                    }
                })
        },
            
            funcGetGasPrice: { (coreClient, coreEWM, wid, rid) in
                guard let client = coreClient.map ({ Unmanaged<AnyEthereumClient>.fromOpaque($0).takeUnretainedValue() }),
                    let ewm = EthereumWalletManager.lookup(core: coreEWM),
                    let wallet = ewm.findWallet(withIdentifier: wid) else { return }
                assert (ewm.client === client.base)
                client.getGasPrice (wallet: wallet, completion: { gasPrice in
                    ewm.serialAsync {
                        ewmAnnounceGasPrice(coreEWM, wid, gasPrice, rid)
                    }
                })
        },

            funcEstimateGas: { (coreClient, coreEWM, wid, tid, from, to, amount, data, rid)  in
                guard let client = coreClient.map ({ Unmanaged<AnyEthereumClient>.fromOpaque($0).takeUnretainedValue() }),
                    let ewm = EthereumWalletManager.lookup(core: coreEWM),
                    let wallet = ewm.findWallet(withIdentifier: wid) else { return }
                let from = asUTF8String(from!)
                let to = asUTF8String(to!)
                let data = asUTF8String(data!)
                let amount = asUTF8String(amount!)
                client.getGasEstimate(wallet: wallet,
                                      tid: tid,
                                      from: from,
                                      to: to,
                                      amount: amount,
                                      data: data,
                                      completion: { gasEstimate in
                                        ewm.serialAsync {
                                            ewmAnnounceGasEstimate(coreEWM, wid, tid, gasEstimate, rid)
                                        }
                })
        },

            funcSubmitTransaction: { (coreClient, coreEWM, wid, tid, transaction, rid)  in
                guard let client = coreClient.map ({ Unmanaged<AnyEthereumClient>.fromOpaque($0).takeUnretainedValue() }),
                    let ewm = EthereumWalletManager.lookup(core: coreEWM),
                    let wallet = ewm.findWallet(withIdentifier: wid) else { return }
                let transaction = asUTF8String(transaction!)
                client.submitTransaction(wallet: wallet, tid: tid,
                                         rawTransaction: transaction,
                                         completion: { result in
                                            ewm.serialAsync {
                                                switch result {
                                                case .success(let hash):
                                                    ewmAnnounceSubmitTransfer(coreEWM, wid, tid, hash, -1, nil, rid)
                                                case .error(let error):
                                                    if case .rpcError(let rpcError) = error {
                                                        ewmAnnounceSubmitTransfer(coreEWM, wid, tid, nil, Int32(rpcError.code), rpcError.message, rid)
                                                    } else {
                                                        ewmAnnounceSubmitTransfer(coreEWM, wid, tid, nil, -1, "unknown", rid)
                                                    }
                                                }
                                            }
                })
        },
            
            funcGetTransactions: { (coreClient, coreEWM, address, begBlockNumber, endBlockNumber, rid) in
                guard let client = coreClient.map ({ Unmanaged<AnyEthereumClient>.fromOpaque($0).takeUnretainedValue() }),
                    let ewm = EthereumWalletManager.lookup(core: coreEWM) else { return }
                let address = asUTF8String(address!)
                client.getTransactions(address: address, blockStart: begBlockNumber, blockStop: endBlockNumber, completion: { result in
                    ewm.serialAsync {
                        switch result {
                        case .success(let txs):
                            txs.forEach {
                                ewmAnnounceTransaction(coreEWM,
                                                       rid,
                                                       $0.hash,
                                                       $0.from,
                                                       $0.to,
                                                       nil,
                                                       $0.value,
                                                       $0.gas,
                                                       $0.gasPrice,
                                                       $0.input,
                                                       $0.nonce,
                                                       $0.gasUsed,
                                                       $0.blockNumber,
                                                       $0.blockHash,
                                                       $0.confirmations,
                                                       $0.transactionIndex,
                                                       $0.timeStamp,
                                                       $0.isError)
                            }
                            ewmAnnounceTransactionComplete(coreEWM, rid, ETHEREUM_BOOLEAN_TRUE)

                        case .error:
                            ewmAnnounceTransactionComplete(coreEWM, rid, ETHEREUM_BOOLEAN_FALSE)
                        }
                    }
                })
        },
            
            funcGetLogs: { (coreClient, coreEWM, _, address, event, begBlockNumber, endBlockNumber, rid) in
                guard let client = coreClient.map ({ Unmanaged<AnyEthereumClient>.fromOpaque($0).takeUnretainedValue() }),
                    let ewm = EthereumWalletManager.lookup(core: coreEWM) else { return }
                let address = asUTF8String(address!)
                let event = asUTF8String(event!)
                client.getLogs (address: address,
                                event: event,
                                blockStart: begBlockNumber,
                                blockStop: endBlockNumber,
                                completion: { result in
                                    ewm.serialAsync {
                                        switch result {
                                        case .success(let logs):
                                            for log in logs {
                                                // only announce logs within the requested block range since the backend does not filter
                                                guard let blockNumber = UInt64(log.blockNumber.withoutHexPrefix, radix: 16) else {
                                                    ewmAnnounceLogComplete(coreEWM, rid, ETHEREUM_BOOLEAN_FALSE)
                                                    break
                                                }
                                                guard (begBlockNumber...endBlockNumber).contains(blockNumber) else {
                                                    continue
                                                }
                                                var cTopics = log.topics.filter { !$0.isEmpty }.map { UnsafePointer<Int8>(strdup($0)) }
                                                defer { cTopics.forEach { free(UnsafeMutablePointer(mutating: $0)) } }
                                                ewmAnnounceLog(coreEWM,
                                                               rid,
                                                               log.transactionHash,
                                                               log.address,
                                                               Int32(cTopics.count),
                                                               &cTopics,
                                                               log.data,
                                                               log.gasPrice,
                                                               log.gasUsed,
                                                               log.logIndex,
                                                               log.blockNumber,
                                                               log.transactionIndex,
                                                               log.timeStamp)
                                            }
                                            ewmAnnounceLogComplete(coreEWM, rid, ETHEREUM_BOOLEAN_TRUE)

                                        case .error:
                                            ewmAnnounceLogComplete(coreEWM, rid, ETHEREUM_BOOLEAN_FALSE)
                                        }
                                    }
                })
        },

            funcGetBlocks: { (coreClient, coreEWM, address, interests, blockStart, blockStop, rid) in
                guard let client = coreClient.map ({ Unmanaged<AnyEthereumClient>.fromOpaque($0).takeUnretainedValue() }),
                    let ewm = EthereumWalletManager.lookup(core: coreEWM) else { return }
                let address = asUTF8String(address!)
                    client.getBlocks (ewm: ewm,
                                      address: address,
                                      interests: interests,
                                      blockStart: blockStart,
                                      blockStop: blockStop,
                                      rid: rid) // TODO: announce blocks
        },

            funcGetTokens: { (coreClient, coreEWM, rid) in
                guard let client = coreClient.map ({ Unmanaged<AnyEthereumClient>.fromOpaque($0).takeUnretainedValue() }),
                    let ewm = EthereumWalletManager.lookup(core: coreEWM) else { return }
                client.getTokens(ewm: ewm, rid: rid) // TODO: announce tokens
        },

            funcGetBlockNumber: { (coreClient, coreEWM, rid) in
                guard let client = coreClient.map ({ Unmanaged<AnyEthereumClient>.fromOpaque($0).takeUnretainedValue() }),
                    let ewm = EthereumWalletManager.lookup(core: coreEWM) else { return }
                client.getBlockNumber { blockNumber in
                    ewm.serialAsync {
                        ewmAnnounceBlockNumber(coreEWM, blockNumber, rid)
                    }
                }
        },

            funcGetNonce: { (coreClient, coreEWM, address, rid) in
                guard let client = coreClient.map ({ Unmanaged<AnyEthereumClient>.fromOpaque($0).takeUnretainedValue() }),
                    let ewm = EthereumWalletManager.lookup(core: coreEWM) else { return }
                let address = asUTF8String(address!)
                client.getNonce(address: address) { nonce in
                    ewm.serialAsync {
                        ewmAnnounceNonce(coreEWM, address, nonce, rid)
                    }
                }
        },

            // Event Callbacks

            funcEWMEvent: { (coreClient, coreEWM, event, _, _) in
                guard let client = coreClient.map ({ Unmanaged<AnyEthereumClient>.fromOpaque($0).takeUnretainedValue() }),
                    let ewm = EthereumWalletManager.lookup(core: coreEWM) else { return }
                ewm.serialAsync {
                    client.handleEWMEvent (ewm: ewm, event: EthereumEWMEvent (event))
                }
        },

            funcPeerEvent: { (coreClient, coreEWM, event, _, _) in
                guard let client = coreClient.map ({ Unmanaged<AnyEthereumClient>.fromOpaque($0).takeUnretainedValue() }),
                    let ewm = EthereumWalletManager.lookup(core: coreEWM) else { return }
                ewm.serialAsync {
                    client.handlePeerEvent (ewm: ewm, event: EthereumPeerEvent (event))
                }
        },

            funcWalletEvent: { (coreClient, coreEWM, wid, event, _, _) in
                guard let client = coreClient.map ({ Unmanaged<AnyEthereumClient>.fromOpaque($0).takeUnretainedValue() }),
                    let ewm = EthereumWalletManager.lookup(core: coreEWM),
                    let wid = wid else { return }
                ewm.serialAsync {
                    var wallet: EthereumWallet?
                    // token wallet creation can be triggered by the app or by core
                    // this handles the case where core initiated wallet creation
                    if event == WALLET_EVENT_CREATED, let token = ewm.tokenForWallet(withIdentifier: wid) {
                        print("[BRETH] token wallet creation event: \(token.code)")
                        wallet = ewm.handleWalletCreation(wid: wid, currency: token)
                    } else {
                        wallet = ewm.findWallet(withIdentifier: wid)
                    }
                    guard wallet != nil else { return assertionFailure("[EWM] WARNING: event for unknown wallet: \(event)") }
                    client.handleWalletEvent(ewm: ewm,
                                             wallet: wallet!,
                                             event: EthereumWalletEvent (event))
                }
        },

            funcTokenEvent: { (coreClient, coreEWM, token, event) in
                guard let client = coreClient.map ({ Unmanaged<AnyEthereumClient>.fromOpaque($0).takeUnretainedValue() }),
                    let ewm = EthereumWalletManager.lookup(core: coreEWM),
                    let token = token else { return }
                ewm.serialAsync {
                    guard let token = ewm.findToken(coreToken: token) else { return }
                    client.handleTokenEvent(ewm: ewm,
                                            token: token,
                                            event: EthereumTokenEvent (event))
                }
        },

            funcTransferEvent: { (coreClient, coreEWM, wid, tid, event, _, _) in
                guard let client = coreClient.map ({ Unmanaged<AnyEthereumClient>.fromOpaque($0).takeUnretainedValue() }),
                    let ewm = EthereumWalletManager.lookup(core: coreEWM),
                    let wallet = ewm.findWallet(withIdentifier: wid) else { return }
                ewm.serialAsync {
                    client.handleTransferEvent(ewm: ewm,
                                               wallet: wallet,
                                               transfer: ewm.findTransaction(currency: wallet.currency, identifier: tid),
                                               event: EthereumTransferEvent(event))
                }
        })
    }
    
    //
    // All Ethereum Wallet Managers
    //

    private static var all: [Weak<EthereumWalletManager>] = []

    private static func add (_ ewm: EthereumWalletManager) {
        all.append(Weak(value: ewm))
    }

    private static func lookup (core: BREthereumEWM?) -> EthereumWalletManager? {
        guard let core = core else { return nil }
        return all
            .filter { nil != $0.value }
            .map { $0.value! }
            .first { $0.core == core }
    }

    //
    // Hash Data Pair Set
    //
    private static func asPairs (_ set: [String: String]) -> OpaquePointer {
        let pairs = hashDataPairSetCreateEmpty(set.count)!
        set.forEach { (hash: String, data: String) in
            hashDataPairAdd (pairs, hash, data)
        }
        return pairs
    }

    private static func asDictionary (_ set: OpaquePointer) -> [String: String] {
        var dict: [String: String] = [:]

        var pair: BREthereumHashDataPair?
        while let p = OpaquePointer.init (BRSetIterate (set, &pair)) {
            let cStrHash = hashDataPairGetHashAsString (p)!
            let cStrData = hashDataPairGetDataAsString (p)!

            dict [String (cString: cStrHash)] = String (cString: cStrData)

            free (cStrHash); free (cStrData)

            pair = p
        }

        return dict
    }
}

// MARK: - Any Client

///
/// Concretize protocol EthereumClient
///
class AnyEthereumClient: EthereumClient {
    let base: EthereumClient

    init (base: EthereumClient) {
        self.base = base
    }

    func getGasPrice(wallet: EthereumWallet, completion: @escaping AmountHandler) {
        base.getGasPrice(wallet: wallet, completion: completion)
    }

    func getGasEstimate(wallet: EthereumWallet, tid: EthereumTransactionId, from: String, to: String, amount: String, data: String, completion: @escaping AmountHandler) {
        base.getGasEstimate(wallet: wallet, tid: tid, from: from, to: to, amount: amount, data: data, completion: completion)
    }

    func getBalance(wallet: EthereumWallet, address: String, completion: @escaping AmountHandler) {
        base.getBalance(wallet: wallet, address: address, completion: completion)
    }

    func submitTransaction(wallet: EthereumWallet, tid: EthereumTransactionId, rawTransaction: String, completion: @escaping SubmitTransactionHandler) {
        base.submitTransaction(wallet: wallet, tid: tid, rawTransaction: rawTransaction, completion: completion)
    }

    func getTransactions(address: String, blockStart: UInt64, blockStop: UInt64, completion: @escaping TransactionsHandler) {
        base.getTransactions(address: address, blockStart: blockStart, blockStop: blockStop, completion: completion)
    }

    func getLogs(address: String, event: String, blockStart: UInt64, blockStop: UInt64, completion: @escaping LogsHandler) {
        base.getLogs(address: address, event: event, blockStart: blockStart, blockStop: blockStop, completion: completion)
    }

    func getBlocks (ewm: EthereumWalletManager, address: String, interests: UInt32, blockStart: UInt64, blockStop: UInt64, rid: Int32) {
        base.getBlocks (ewm: ewm, address: address, interests: interests, blockStart: blockStart, blockStop: blockStop, rid: rid)
    }

    func getTokens (ewm: EthereumWalletManager, rid: Int32) {
        base.getTokens(ewm: ewm, rid: rid)
    }

    func getBlockNumber(completion: @escaping AmountHandler) {
        base.getBlockNumber(completion: completion)
    }

    func getNonce(address: String, completion: @escaping AmountHandler) {
        base.getNonce(address: address, completion: completion)
    }

    func handleEWMEvent(ewm: EthereumWalletManager, event: EthereumEWMEvent) {
        base.handleEWMEvent(ewm: ewm, event: event)
    }

    func handlePeerEvent(ewm: EthereumWalletManager, event: EthereumPeerEvent) {
        base.handlePeerEvent(ewm: ewm, event: event)
    }

    func handleWalletEvent(ewm: EthereumWalletManager, wallet: EthereumWallet, event: EthereumWalletEvent) {
        base.handleWalletEvent(ewm: ewm, wallet: wallet, event: event)
    }

    func handleTokenEvent(ewm: EthereumWalletManager, token: ERC20Token, event: EthereumTokenEvent) {
        base.handleTokenEvent(ewm: ewm, token: token, event: event)
    }

    func handleTransferEvent(ewm: EthereumWalletManager, wallet: EthereumWallet, transfer: EthereumTransfer, event: EthereumTransferEvent) {
        base.handleTransferEvent(ewm: ewm, wallet: wallet, transfer: transfer, event: event)
    }
}

// MARK: - Helpers

private func asUTF8String (_ chars: UnsafeMutablePointer<CChar>, _ release: Bool = false ) -> String {
    let result = String (cString: chars, encoding: .utf8)!
    if release { free (chars) }
    return result
}

private func asUTF8String (_ chars: UnsafePointer<CChar>) -> String {
    return String (cString: chars, encoding: .utf8)!
}

struct Weak<T: AnyObject> {
    weak var value: T?
    init (value: T) {
        self.value = value
    }
}
