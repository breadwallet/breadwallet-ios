//
//  BREthereum.swift
//  breadwallet
//
//  Created by Ed Gamble on 3/28/18.
//  Copyright © 2018 breadwallet LLC. All rights reserved.
//

import Foundation
import BRCore.Ethereum

typealias EthereumReferenceId = Int32
typealias EthereumWalletId = EthereumReferenceId
typealias EthereumTransactionId = EthereumReferenceId
typealias EthereumAccountId = EthereumReferenceId
typealias EthereumAddressId = EthereumReferenceId
typealias EthereumBlockId = EthereumReferenceId
typealias EthereumListenerId = EthereumReferenceId

// Access to BRCore/BREthereum types
typealias BRCoreEthereumLightNode = OpaquePointer

/// Swift wrapper for BREthereumWalletEvent
enum EthereumWalletEvent {
    case created
    case balanceUpdated
    case gasLimitUpdated
    case gasPriceUpdated
    case deleted
    
    init(_ event: BREthereumWalletEvent) {
        switch event {
        case WALLET_EVENT_CREATED:                      self = .created
        case WALLET_EVENT_BALANCE_UPDATED:              self = .balanceUpdated
        case WALLET_EVENT_DEFAULT_GAS_LIMIT_UPDATED:    self = .gasLimitUpdated
        case WALLET_EVENT_DEFAULT_GAS_PRICE_UPDATED:    self = .gasPriceUpdated
        case WALLET_EVENT_DELETED:                      self = .deleted
        default:
            assertionFailure()
            self = .created
        }
    }
}

/// Swift wrapper for BREthereumTransactionEvent
enum EthereumTransactionEvent {
    case added
    case removed
    case created
    case signed
    case submitted
    case confirmed
    case errored
    case gasEstimateUpdated
    case confirmationsUpdated
    
    init(_ event: BREthereumTransactionEvent) {
        switch event {
        case TRANSACTION_EVENT_ADDED:                       self = .added
        case TRANSACTION_EVENT_REMOVED:                     self = .removed
        case TRANSACTION_EVENT_CREATED:                     self = .created
        case TRANSACTION_EVENT_SIGNED:                      self = .signed
        case TRANSACTION_EVENT_SUBMITTED:                   self = .submitted
        case TRANSACTION_EVENT_BLOCKED:                     self = .confirmed
        case TRANSACTION_EVENT_ERRORED:                     self = .errored
        case TRANSACTION_EVENT_GAS_ESTIMATE_UPDATED:        self = .gasEstimateUpdated
        case TRANSACTION_EVENT_BLOCK_CONFIRMATIONS_UPDATED: self = .confirmationsUpdated
        default:
            assertionFailure()
            self = .added
        }
    }
}

// MARK: Reference

///
/// Core Ethereum *does not* allow direct access to Core 'C' Memory; instead we use references
/// within an `EthereumLightNode`.  This allows the Core to avoid multiprocessing issues arising
/// from Client access in arbitrary threads.  Additionally, the Core is free to manage its own
/// memory w/o regard to a Client holding a reference (that the Core can never, even know about).
///
/// Attemping to access a Core reference that no longer exists in the Core results in an error.
/// But how so is TBD.
///
/// An EthereumReference is Equatable based on the `EthereumLightNode` and the identifier (of the
/// reference).  Generally adopters of `EthereumReference` will be structures as all their
/// properties are computed via a C function on `EthereumLightNode`.
///
protocol EthereumReference : Equatable  {
    associatedtype ReferenceType : Equatable
    
    var node : EthereumLightNode! { get }
    
    var identifier : ReferenceType { get }
}

extension EthereumReference {
    static func == (lhs: Self, rhs: Self) -> Bool {
        return rhs.node === lhs.node && rhs.identifier == lhs.identifier
    }
}

// MARK: - Pointer

///
/// An `EthereumPointer` holds an `OpaquePointer` to Ethereum Core memory.  This is used for
/// 'constant-like' memory references.
///
fileprivate protocol EthereumPointer : Equatable {
    associatedtype PointerType : Equatable

    var core : PointerType { get }
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
    
    var chainId :Int {
        return Int(exactly: networkGetChainId (core))!
    }
}

// MARK: - Token

extension ERC20Token: EthereumPointer {
    var core: BREthereumToken {
        let token = tokenLookup(self.address)
        assert(token != nil || E.isTestnet, "missing token in core: \(self.code)")
        return token!
    }
}

// MARK: - Wallet

///
/// An `EthereumWallet` holds a balance and transactions of ETHER or a TOKEN
///
struct EthereumWallet : EthereumReference {
    weak var node : EthereumLightNode!
    let identifier : EthereumWalletId
    let currency: CurrencyDef
    
    //
    // MARK: Gas Limit
    //
    var defaultGasLimit : UInt64 {
        get {
            return ethereumWalletGetDefaultGasLimit (node.core, identifier)
        }
        set (value) {
            ethereumWalletSetDefaultGasLimit (node.core, identifier, value)
        }
    }
    
    func gasEstimate (transaction: EthereumTransaction) -> UInt64 {
        return ethereumWalletGetGasEstimate (self.node!.core, self.identifier, transaction.identifier)
    }
    
    //
    // MARK: Gas Price
    //
    static let maximumGasPrice : UInt64 = 100000000000000
    
    var defaultGasPrice : UInt64 {
        return ethereumWalletGetDefaultGasPrice (self.node!.core, self.identifier)
    }
    
    func setDefaultGasPrice(_ value: UInt64) {
        precondition(value <= EthereumWallet.maximumGasPrice)
        ethereumWalletSetDefaultGasPrice (self.node!.core, self.identifier, WEI, value)
    }
    
    //
    // MARK: Balance
    //
    var balance : UInt256 {
        let amount : BREthereumAmount = ethereumWalletGetBalance(node.core, identifier)
        return (AMOUNT_ETHER == amount.type)
            ? amount.u.ether.valueInWEI
            : amount.u.tokenQuantity.valueAsInteger
    }
    
    //
    // MARK: Constructor
    //
    internal init (node : EthereumLightNode,
                   wid : EthereumWalletId,
                   currency : CurrencyDef) {
        self.node = node
        self.identifier = wid
        self.currency = currency
    }
    
    //
    // MARK: Transaction
    //
    func createTransaction (currency: CurrencyDef, recvAddress: String, amount: UInt256) -> EthereumTransaction {
        var coreAmount: BREthereumAmount
        if let token = currency as? ERC20Token {
            coreAmount = amountCreateToken(createTokenQuantity(token.core, amount))
        } else {
            coreAmount = amountCreateEther(etherCreate(amount))
        }

        let tid = ethereumWalletCreateTransaction (node.core,
                                                   identifier,
                                                   recvAddress,
                                                   coreAmount)
        return EthereumTransaction (node: node, currency: currency, identifier: tid)
    }
    
    /// Create a contract execution transaction. Amount is ETH (in wei) and data is the ABI payload (hex-encoded string)
    /// Optionally specify gasPrice and gasLimit to use, otherwise defaults will be used.
    func createContractTransaction (recvAddress: String, amount: UInt256, data: String, gasPrice: UInt256? = nil, gasLimit: UInt64? = nil) -> EthereumTransaction {
        let coreAmount = etherCreate(amount)
        let gasPrice = gasPrice ?? UInt256(defaultGasPrice)
        let gasLimit = gasLimit ?? defaultGasLimit
        
        let tid = ethereumWalletCreateTransactionGeneric (node.core,
                                                          identifier,
                                                          recvAddress,
                                                          coreAmount,
                                                          gasPriceCreate(etherCreate(gasPrice)),
                                                          gasCreate(gasLimit),
                                                          data)
        return EthereumTransaction (node: node, currency: currency, identifier: tid)
    }
    
    func sign (transaction: EthereumTransaction, privateKey: BRKey) {
        ethereumWalletSignTransactionWithPrivateKey (self.node!.core, self.identifier, transaction.identifier, privateKey)
    }
    
    func rawTransactionHexEncoded(_ transaction: EthereumTransaction) -> String {
        return asUTF8String (lightNodeGetTransactionRawDataHexEncoded (self.node!.core, self.identifier, transaction.identifier, "0x"))
    }
    
    /// Triggers submitTransaction callback on EthereumClient
    func submit (transaction : EthereumTransaction) {
        ethereumWalletSubmitTransaction (self.node!.core, self.identifier, transaction.identifier)
    }
    
    /// Call after successful submission of a transaction when bypassing the submitTransaction client callback
    func announceSubmitTransaction(_ transaction : EthereumTransaction, hash: String) {
        lightNodeAnnounceSubmitTransaction(self.node!.core, self.identifier, transaction.identifier, hash, 0)
    }
    
    var transactions : [EthereumTransaction] {
        let count = ethereumWalletGetTransactionCount (self.node!.core, self.identifier)
        let identifiers = ethereumWalletGetTransactions (self.node!.core, self.identifier)
        return UnsafeBufferPointer (start: identifiers, count: Int(exactly: count)!)
            .map { self.node!.findTransaction(currency: self.currency, identifier: $0) }
    }
    
    var transactionsCount : Int {
        return Int (exactly: ethereumWalletGetTransactionCount (self.node!.core, self.identifier))!
    }
    
    //
    // MARK: Update
    //
    
    /// Trigger update of wallet's balance
    func updateBalance() {
        lightNodeUpdateWalletBalance(self.node!.core, identifier)
    }
    
    /// Trigger update of wallet's transactions
    func updateTransactions() {
        if currency is ERC20Token {
            lightNodeUpdateLogs(node.core, identifier, functionERC20Transfer)
        } else {
            lightNodeUpdateTransactions(node.core)
        }
    }
    
    func updateDefaultGasPrice() {
        lightNodeUpdateWalletDefaultGasPrice(node.core, identifier)
    }
}

// MARK: - Block

///
/// An `EthereumBlock` represents a  ...
///
struct EthereumBlock : EthereumReference {
    weak var node : EthereumLightNode!
    let identifier : EthereumWalletId

    init (node: EthereumLightNode, identifier: EthereumAccountId) {
        self.node = node
        self.identifier = identifier
    }

    var number : UInt64 {
        return ethereumBlockGetNumber (self.node!.core, identifier)
    }

    var timestamp : UInt64 {
        return ethereumBlockGetTimestamp (self.node!.core, identifier)
    }

    var hash : String {
        return asUTF8String(ethereumBlockGetHash (self.node!.core, identifier))
    }
}

// MARK: - Transaction

///
/// An `EthereumTransaction` represents a transfer of ETHER or a specific TOKEN between two
/// accounts.
///
struct EthereumTransaction : EthereumReference {//EthereumReferenceWithDefaultUnit {
    weak var node : EthereumLightNode!
    let identifier : EthereumTransactionId
    let currency: CurrencyDef

    internal init (node : EthereumLightNode, currency: CurrencyDef, identifier : EthereumTransactionId) {
        self.node = node
        self.identifier = identifier
        self.currency = currency
    }

    var hash : String {
        return asUTF8String (ethereumTransactionGetHash (self.node!.core, self.identifier), true)
    }

    var sourceAddress : String {
        return asUTF8String (ethereumTransactionGetSendAddress (self.node!.core, self.identifier), true)
    }

    var targetAddress : String {
        return asUTF8String (ethereumTransactionGetRecvAddress (self.node!.core, self.identifier), true)
    }

    var amount : UInt256 {
        let amount : BREthereumAmount = ethereumTransactionGetAmount (self.node!.core, self.identifier)
        return (AMOUNT_ETHER == amount.type)
            ? amount.u.ether.valueInWEI
            : amount.u.tokenQuantity.valueAsInteger
    }

    var gasPrice : UInt256 {
        let price : BREthereumAmount = ethereumTransactionGetGasPriceToo (self.node!.core, self.identifier)
        return price.u.ether.valueInWEI
    }

    var gasLimit : UInt64 {
        return ethereumTransactionGetGasLimit(self.node!.core, self.identifier)
    }

    var gasUsed : UInt64 {
        return ethereumTransactionGetGasUsed (self.node!.core, self.identifier)
    }

    var nonce : UInt64 {
        return ethereumTransactionGetNonce (self.node!.core, self.identifier)
    }

    var blockNumber : UInt64 {
        return ethereumTransactionGetBlockNumber (self.node!.core, self.identifier)
    }

    var blockTimestamp : UInt64 {
        return ethereumTransactionGetBlockTimestamp (self.node!.core, self.identifier)
    }
    
    var confirmations: UInt64 {
        return ethereumTransactionGetBlockConfirmations(self.node!.core, self.identifier)
    }
}

// MARK: - Client

///
/// An `EthereumClient` is a protocol defined with a set of functions that support an
/// EthereumLightNode.
///
protocol EthereumClient : class {
    typealias AmountHandler = (String) -> Void
    typealias SubmitTransactionHandler = (String) -> Void
    typealias TransactionsHandler = ([EthTxJSON]) -> Void
    typealias LogsHandler = ([EthLogEventJSON]) -> Void
    
    func getGasPrice (wallet: EthereumWallet, completion: @escaping AmountHandler) -> Void
    func getGasEstimate (wallet: EthereumWallet,
                         tid: EthereumTransactionId,
                         to: String,
                         amount: String,
                         data:  String,
                         completion: @escaping AmountHandler) -> Void
    
    func getBalance (wallet: EthereumWallet, address: String, completion: @escaping AmountHandler) -> Void
    
    func submitTransaction (wallet: EthereumWallet,
                            tid: EthereumTransactionId,
                            rawTransaction: String,
                            completion: @escaping SubmitTransactionHandler) -> Void

    func getTransactions (address: String, completion: @escaping TransactionsHandler) -> Void
    
    func getLogs (address: String, contract: String?, event: String, completion: @escaping LogsHandler) -> Void
    
    func getBlockNumber(completion: @escaping AmountHandler) -> Void
    
    func getNonce(address: String, completion: @escaping AmountHandler) -> Void
}

// MARK: - Listener

///
/// An `EthereumListener` listen to changed in a Light Node.
///
protocol EthereumListener {
    func handleWalletEvent (wallet: EthereumWallet,
                            event: EthereumWalletEvent,
                            status: BREthereumStatus,
                            errorDesc: String?) -> Void
    
    func handleBlockEvent (block: EthereumBlock,
                           event: BREthereumBlockEvent,
                           status: BREthereumStatus,
                           errorDesc: String?) -> Void
    
    func handleTransactionEvent (wallet: EthereumWallet,
                                 transaction: EthereumTransaction,
                                 event: EthereumTransactionEvent,
                                 status: BREthereumStatus,
                                 errorDesc: String?) -> Void
}

// MARK: - LightNode

///
/// An `EthereumLightNode` is a SPV/LES (Simplified Payment Verification / Light Ethereum
/// Subprotocol) node in an Ethereum Network.
///
class EthereumLightNode: EthereumPointer {
    
    ///
    /// The OpaquePointer to the 'Core Ethereum LightNode'.  We defer nearly all functions
    /// to this reference.
    ///
    let core : BRCoreEthereumLightNode
    
    ///
    /// The client ...
    ///
    weak private(set) var client : EthereumClient?
    
    ///
    /// The listener ...
    ///
    private(set) var listener : EthereumListener?
    
    ///
    /// The network ...
    ///
    let network : EthereumNetwork
    
    lazy var address: String = {
        let cString = ethereumGetAccountPrimaryAddress (core)
        let string = String (cString: cString!)
        free (cString)
        return string
    }()
    
    private init (core: BRCoreEthereumLightNode,
                  client : EthereumClient,
                  listener: EthereumListener?,
                  network: EthereumNetwork) {
        self.core = core
        self.client = client
        self.listener = listener
        self.network = network
        self.coreClient = createCoreClient(client: client)
        addListenerCallbacks(listener: listener)
    }
    
    convenience init (client : EthereumClient,
                      listener: EthereumListener?,
                      network : EthereumNetwork,
                      publicKey : BRKey) {
        self.init (core: ethereumCreateWithPublicKey (network.core, publicKey),
                   client: client,
                   listener: listener,
                   network: network)
    }
    
    //
    // MARK: Tokens
    //
    func setTokens(_ tokens: [ERC20Token]) {
        for token in tokens {
            lightNodeAnnounceToken(core,
                                   token.address,
                                   token.symbol,
                                   token.code,
                                   token.name,
                                   Int32(token.decimals),
                                   nil, // gas limit
                                   nil, // gas price
                                   0)
        }
    }
    
    //
    // MARK: Wallets
    //
    private var walletsByTicker: [String: EthereumWallet] = [:]
    private var walletsById: [EthereumWalletId: EthereumWallet] = [:]
    
    func findWallet(withIdentifier identifier: EthereumWalletId) -> EthereumWallet? {
        return walletsById[identifier]
    }
    
    func findWallet(forCurrency currency: CurrencyDef) -> EthereumWallet? {
        return walletsByTicker[currency.code]
    }
    
    func wallet(_ currency: CurrencyDef) -> EthereumWallet {
        if let wallet = walletsByTicker[currency.code] {
            return wallet
        }
        
        var identifier: EthereumWalletId
        
        if let token = currency as? ERC20Token {
            identifier = ethereumGetWalletHoldingToken(core, token.core)
        } else {
            identifier = ethereumGetWallet(core)
        }
        
        let wallet = EthereumWallet(node: self, wid: identifier, currency: currency)
        walletsById[identifier] = wallet
        walletsByTicker[currency.code] = wallet
        
        print("[BRETH] create wallet \(currency.code)")
        
        return wallet
    }
    
    func currency(forWalletId wid: EthereumWalletId) -> CurrencyDef? {
        return walletsById[wid]?.currency
    }
    
    /// Sets default gas price on all wallets
    func updateDefaultGasPrice(_ gasPrice: UInt256) {
        walletsById.values.forEach { $0.setDefaultGasPrice(gasPrice.asUInt64) }
    }
    
    //
    // Block
    //
    internal func findBlock (identifier: EthereumBlockId) -> EthereumBlock {
        return EthereumBlock (node: self, identifier: identifier);
    }
    
    var blockHeight : UInt64 {
        return ethereumGetBlockHeight (core)
    }
    
    //
    // Transactions
    //
    internal func findTransaction (currency: CurrencyDef, identifier: EthereumTransactionId) -> EthereumTransaction {
        return EthereumTransaction (node: self, currency: currency, identifier: identifier)
    }
    
    //
    // Listener Callbacks
    //
    var lid : BREthereumListenerId?
    
    internal func addListenerCallbacks (listener: EthereumListener?) {
        guard (listener != nil) else { return }
        lid = lightNodeAddListener (
            core,
            UnsafeMutableRawPointer (Unmanaged.passUnretained(self).toOpaque()),
            // handleWalletEvent
            { (this, core, wid, event, status, error) in
                if let this = this.map ({ Unmanaged<EthereumLightNode>.fromOpaque($0).takeUnretainedValue() }) {
                    assert (this.core == core)
                    guard let wallet = this.findWallet(withIdentifier: wid) else { return }
                    this.listener?.handleWalletEvent (wallet: wallet,
                                                      event: EthereumWalletEvent(event),
                                                      status: status,
                                                      errorDesc: error.map { asUTF8String($0)})
                    
                }
                return },
            
            // handleBlockEvent
            { (this, core, bid, event, status, error) in
                if let this = this.map ({ Unmanaged<EthereumLightNode>.fromOpaque($0).takeUnretainedValue() }) {
                    assert (this.core == core)
                    this.listener?.handleBlockEvent (block: this.findBlock (identifier: bid),
                                                     event: event,
                                                     status: status,
                                                     errorDesc: error.map { asUTF8String($0)});
                }
                return },
            
            // handleTransactionEvent
            { (this, core, wid, tid, event, status, error) in
                if let this = this.map ({ Unmanaged<EthereumLightNode>.fromOpaque($0).takeUnretainedValue() }) {
                    assert (this.core == core)
                    guard let wallet = this.findWallet(withIdentifier: wid) else { return }
                    this.listener?.handleTransactionEvent (wallet: wallet,
                                                           transaction: this.findTransaction(currency: wallet.currency, identifier: tid),
                                                           event: EthereumTransactionEvent(event),
                                                           status: status,
                                                           errorDesc: error.map { asUTF8String($0)})
                }
                return })
    }
    
    //
    // Connect / Disconnect
    //
    private var coreClient : BREthereumClient?
    
    func connect () {
        guard let client = coreClient else { return }
        ethereumConnect (self.core, client);
    }
    
    func disconnect () {
        ethereumDisconnect (self.core)
    }
    
    ///
    /// Create an BREthereumLightNodeConfiguration for a JSON_RPC client.  The configuration
    /// will invoke Client functions for LightNode callbacks, implementing, for example,
    /// getTransactions().  In this case, the client is expected to make a JSON_RPC call
    /// returning a list of JSON transactions and then to processing each transaction by
    /// calling announceTransaction().
    ///
    func createCoreClient (client: EthereumClient) -> BREthereumClient {
        return ethereumClientCreate (
            UnsafeMutableRawPointer (Unmanaged.passUnretained(self).toOpaque()),
            //  JsonRpcGetBalance funcGetBalance,
            { (this, core, wid, address, rid) in
                guard let this = this.map ({ Unmanaged<EthereumLightNode>.fromOpaque($0).takeUnretainedValue() }),
                    let wallet = this.findWallet(withIdentifier: wid) else { return }
                this.client?.getBalance(wallet: wallet, address: asUTF8String(address!), completion: { balance in
                    lightNodeAnnounceBalance (this.core, wid, balance, rid)
                })
                
        },
            
            //JsonRpcGetGasPrice functGetGasPrice
            { (this, core, wid, rid) in
                guard let this = this.map ({ Unmanaged<EthereumLightNode>.fromOpaque($0).takeUnretainedValue() }),
                    let wallet = this.findWallet(withIdentifier: wid) else { return }
                this.client?.getGasPrice (wallet: wallet, completion: { gasPrice in
                    lightNodeAnnounceGasPrice (this.core, wid, gasPrice, rid)
                })
        },
            
            // JsonRpcEstimateGas funcEstimateGas,
            { (this, core, wid, tid, to, amount, data, rid)  in
                guard let this = this.map ({ Unmanaged<EthereumLightNode>.fromOpaque($0).takeUnretainedValue() }),
                    let wallet = this.findWallet(withIdentifier: wid) else { return }
                this.client?.getGasEstimate(wallet: wallet, tid: tid,
                                            to: asUTF8String(to!),
                                            amount: asUTF8String(amount!),
                                            data: asUTF8String(data!),
                                            completion: { gasEstimate in
                                                lightNodeAnnounceGasEstimate (this.core, wid, tid, gasEstimate, rid)
                })
        },
            
            // JsonRpcSubmitTransaction funcSubmitTransaction,
            { (this, core, wid, tid, transaction, rid)  in
                guard let this = this.map ({ Unmanaged<EthereumLightNode>.fromOpaque($0).takeUnretainedValue() }),
                    let wallet = this.findWallet(withIdentifier: wid) else { return }
                this.client?.submitTransaction(wallet: wallet, tid: tid,
                                               rawTransaction: asUTF8String(transaction!),
                                               completion: { hash in
                                                lightNodeAnnounceSubmitTransaction (this.core, wid, tid, hash, rid)
                })
        },
            
            // JsonRpcGetTransactions funcGetTransactions
            { (this, core, address, rid) in
                guard let this = this.map ({ Unmanaged<EthereumLightNode>.fromOpaque($0).takeUnretainedValue() }) else { return }
                this.client?.getTransactions(address: asUTF8String(address!), completion: { txs in
                    txs.forEach {
//                        print("announcing tx: \($0.hash)")
                        lightNodeAnnounceTransaction(core,
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
                    
                    
                })
        },
            
            // funcGetLogs
            { (this, core, contract, address, event, rid) in
                guard let this = this.map ({ Unmanaged<EthereumLightNode>.fromOpaque($0).takeUnretainedValue() }) else { return }
                this.client?.getLogs (address: asUTF8String(address!),
                                      contract: contract.map { asUTF8String($0) },
                                      event: asUTF8String(event!),
                                      completion: { logs in
                                        logs.forEach {
                                            var cTopics = $0.topics.map { UnsafePointer<Int8>(strdup($0)) }
                                            defer { cTopics.forEach { free(UnsafeMutablePointer(mutating: $0)) } }
                                            lightNodeAnnounceLog(core,
                                                                 rid,
                                                                 $0.transactionHash,
                                                                 $0.address,
                                                                 Int32($0.topics.count),
                                                                 &cTopics,
                                                                 $0.data,
                                                                 $0.gasPrice,
                                                                 $0.gasUsed,
                                                                 $0.logIndex,
                                                                 $0.blockNumber,
                                                                 $0.transactionIndex,
                                                                 $0.timeStamp)
                                        }
                })
        },
            
            // funcGetBlockNumber
            { (this, core, rid) in
                guard let this = this.map ({ Unmanaged<EthereumLightNode>.fromOpaque($0).takeUnretainedValue() }) else { return }
                this.client?.getBlockNumber(completion: { blockNumber in
                    lightNodeAnnounceBlockNumber(this.core, blockNumber, rid)
                })
        },
            
            // funcGetNonce
            { (this, core, address, rid) in
                guard let this = this.map ({ Unmanaged<EthereumLightNode>.fromOpaque($0).takeUnretainedValue() }),
                address != nil else { return }
                let address = asUTF8String(address!) // the pointer will not be valid in the completion closure
                this.client?.getNonce(address: address, completion: { nonce in
                    lightNodeAnnounceNonce(this.core, address, nonce, rid)
                })
        })
    }
    
    //
    // Nodes
    //
    
    static var nodes : [EthereumLightNode] = []
    
    static func addNode (_ node: EthereumLightNode) {
        nodes.append(node)
    }
    
    static func lookupNode (core: BRCoreEthereumLightNode) -> EthereumLightNode? {
        return nodes.first { $0.core == core }
    }
}


// MARK: - Helpers

private func asUTF8String (_ chars: UnsafeMutablePointer<CChar>, _ release : Bool = false ) -> String {
    let result = String (cString: chars, encoding: .utf8)!
    if (release) { free (chars) }
    return result
}

private func asUTF8String (_ chars: UnsafePointer<CChar>) -> String {
    return String (cString: chars, encoding: .utf8)!
}

