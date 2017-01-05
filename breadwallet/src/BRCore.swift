//
//  BRCore.swift
//  breadwallet
//
//  Created by Aaron Voisine on 12/11/16.
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
import BRCore

typealias BRTxRef = UnsafeMutablePointer<BRTransaction>
typealias BRBlockRef = UnsafeMutablePointer<BRMerkleBlock>

extension BRAddress : CustomStringConvertible {
    public var description: String {
        return String(cString: UnsafeRawPointer([self.s]).assumingMemoryBound(to: CChar.self))
    }
}

extension BRTxInput {
    var address: String {
        return String(cString: UnsafeRawPointer([self.address]).assumingMemoryBound(to: CChar.self))
    }
    
    var script: [UInt8] {
        return [UInt8](UnsafeBufferPointer(start: self.script, count: self.scriptLen))
    }
    
    var signature: [UInt8] {
        return [UInt8](UnsafeBufferPointer(start: self.signature, count: self.sigLen))
    }
}

extension BRTxOutput {
    var address: String {
        return String(cString: UnsafeRawPointer([self.address]).assumingMemoryBound(to: CChar.self))
    }
    
    var script: [UInt8] {
        return [UInt8](UnsafeBufferPointer(start: self.script, count: self.scriptLen))
    }
}

extension BRTransaction {
    var inputs: [BRTxInput] {
        return [BRTxInput](UnsafeBufferPointer(start: self.inputs, count: self.inCount))
    }
    
    var outputs: [BRTxOutput] {
        return [BRTxOutput](UnsafeBufferPointer(start: self.outputs, count: self.outCount))
    }
}

protocol BRWalletListener {
    func balanceChanged(_ balance: UInt64)
    func txAdded(_ tx: BRTxRef)
    func txUpdated(_ txHashes: [UInt256], blockHeight: UInt32, timestamp: UInt32)
    func txDeleted(_ txHash: UInt256, notifyUser: Bool, recommendRescan: Bool)
}

class BRWallet {
    let cPtr: OpaquePointer
    let listener: BRWalletListener
    
    init?(transactions: [BRTxRef?], masterPubKey: BRMasterPubKey, listener: BRWalletListener) {
        var txRefs = transactions
        guard let cPtr = BRWalletNew(&txRefs, txRefs.count, masterPubKey) else { return nil }
        self.listener = listener
        self.cPtr = cPtr
        
        BRWalletSetCallbacks(cPtr, Unmanaged.passUnretained(self).toOpaque(),
        { (info, balance) in // balanceChanged
            guard let info = info else { return }
            Unmanaged<BRWallet>.fromOpaque(info).takeUnretainedValue().listener.balanceChanged(balance)
        },
        { (info, tx) in // txAdded
            guard let info = info, let tx = tx else { return }
            Unmanaged<BRWallet>.fromOpaque(info).takeUnretainedValue().listener.txAdded(tx)
        },
        { (info, txHashes, txCount, blockHeight, timestamp) in // txUpdated
            guard let info = info else { return }
            let hashes = [UInt256](UnsafeBufferPointer(start: txHashes, count: txCount))
            Unmanaged<BRWallet>.fromOpaque(info).takeUnretainedValue().listener.txUpdated(hashes,
                                                                                          blockHeight: blockHeight,
                                                                                          timestamp: timestamp)
        },
        { (info, txHash, notify, rescan) in // txDeleted
            guard let info = info else { return }
            Unmanaged<BRWallet>.fromOpaque(info).takeUnretainedValue().listener.txDeleted(txHash,
                                                                                          notifyUser: notify != 0,
                                                                                          recommendRescan: rescan != 0)
        })
    }
    
    // the first unused external address
    var receiveAddress: String {
        return BRWalletReceiveAddress(cPtr).description
    }
    
    // all previously genereated internal and external addresses
    var allAddresses: [String] {
        var addrs = [BRAddress](repeating: BRAddress(), count: BRWalletAllAddrs(cPtr, nil, 0))
        guard BRWalletAllAddrs(cPtr, &addrs, addrs.count) == addrs.count else { return [] }
        return addrs.map({ $0.description })
    }
    
    // true if the address is a previously generated internal or external address
    func containsAddress(_ address: String) -> Bool {
        return BRWalletContainsAddress(cPtr, address) != 0
    }
    
    // transactions registered in the wallet, sorted by date, oldest first
    var transactions: [BRTxRef?] {
        var transactions = [BRTxRef?](repeating: nil, count: BRWalletTransactions(cPtr, nil, 0))
        guard BRWalletTransactions(cPtr, &transactions, transactions.count) == transactions.count else { return [] }
        return transactions
    }
    
    // current wallet balance, not including transactions known to be invalid
    var balance: UInt64 {
        return BRWalletBalance(cPtr)
    }
    
    // total amount spent from the wallet (exluding change)
    var totalSent: UInt64 {
        return BRWalletTotalSent(cPtr)
    }
    
    // fee-per-kb of transaction size to use when creating a transaction
    var feePerKb: UInt64 {
        get { return BRWalletFeePerKb(cPtr) }
        set (value) { BRWalletSetFeePerKb(cPtr, value) }
    }
    
    // returns an unsigned transaction that sends the specified amount from the wallet to the given address
    func createTransaction(forAmount: UInt64, toAddress: String) -> BRTxRef {
        return BRWalletCreateTransaction(cPtr, forAmount, toAddress)
    }
    
    // returns an unsigned transaction that satisifes the given transaction outputs
    func createTxForOutputs(_ outputs: [BRTxOutput]) -> BRTxRef {
        return BRWalletCreateTxForOutputs(cPtr, outputs, outputs.count)
    }
    
    // signs any inputs in tx that can be signed using private keys from the wallet
    // seed is the master private key (wallet seed) corresponding to the master public key given when wallet was created
    // returns true if all inputs were signed, or false if there was an error or not all inputs were able to be signed
    func signTransaction(_ tx: BRTxRef, seed: inout UInt512) -> Bool {
        return BRWalletSignTransaction(cPtr, tx, &seed.u8.0, MemoryLayout<UInt512>.stride) != 0
    }
    
    // true if no previous wallet transaction spends any of the given transaction's inputs, and no inputs are invalid
    func transactionIsValid(_ tx: BRTxRef) -> Bool {
        return BRWalletTransactionIsValid(cPtr, tx) != 0
    }
    
    // true if transaction cannot be immediately spent (i.e. if it or an input tx can be replaced-by-fee)
    func transactionIsPending(_ tx: BRTxRef) -> Bool {
        return BRWalletTransactionIsPending(cPtr, tx) != 0
    }
    
    // true if tx is considered 0-conf safe (valid and not pending, timestamp greater than 0, and no unverified inputs)
    func transactionIsVerified(_ tx: BRTxRef) -> Bool {
        return BRWalletTransactionIsVerified(cPtr, tx) != 0
    }
    
    // the amount received by the wallet from the transaction (total outputs to change and/or receive addresses)
    func amountReceivedFromTx(_ tx: BRTxRef) -> UInt64 {
        return BRWalletAmountReceivedFromTx(cPtr, tx)
    }
    
    // the amount sent from the wallet by the trasaction (total wallet outputs consumed, change and fee included)
    func amountSentByTx(_ tx: BRTxRef) -> UInt64 {
        return BRWalletAmountSentByTx(cPtr, tx)
    }
    
    // returns the fee for the given transaction if all its inputs are from wallet transactions
    func feeForTx(_ tx: BRTxRef) -> UInt64? {
        let fee = BRWalletFeeForTx(cPtr, tx)
        return fee == UINT64_MAX ? nil : fee
    }
    
    // historical wallet balance after the given transaction, or current balance if tx is not registered in wallet
    func balanceAfterTx(_ tx: BRTxRef) -> UInt64 {
        return BRWalletBalanceAfterTx(cPtr, tx)
    }
    
    // fee that will be added for a transaction of the given size in bytes
    func feeForTxSize(_ size: Int) -> UInt64 {
        return BRWalletFeeForTxSize(cPtr, size)
    }
    
    // outputs below this amount are uneconomical due to fees (TX_MIN_OUTPUT_AMOUNT is the absolute min output amount)
    var minOutputAmount: UInt64 {
        return BRWalletMinOutputAmount(cPtr)
    }
    
    // maximum amount that can be sent from the wallet to a single address after fees
    var maxOutputAmount: UInt64 {
        return BRWalletMaxOutputAmount(cPtr)
    }
    
    deinit {
        BRWalletFree(cPtr)
    }
}

enum BRPeerManagerError: Error {
    case posixError(errorCode: Int32, description: String)
}

protocol BRPeerManagerListener {
    func syncStarted()
    func syncSucceeded()
    func syncFailed(_ error: BRPeerManagerError)
    func txStatusUpdate()
    func saveBlocks(_ blocks: [BRBlockRef?])
    func savePeers(_ peers: [BRPeer])
    func networkIsReachable() -> Bool
}

class BRPeerManager {
    let cPtr: OpaquePointer
    let listener: BRPeerManagerListener
    
    init?(wallet: BRWallet, earliestKeyTime: TimeInterval, blocks: [BRBlockRef?], peers: [BRPeer],
          listener: BRPeerManagerListener) {
        var blockRefs = blocks
        guard let cPtr = BRPeerManagerNew(wallet.cPtr, UInt32(earliestKeyTime + NSTimeIntervalSince1970),
                                          &blockRefs, blockRefs.count, peers, peers.count) else { return nil }
        self.listener = listener
        self.cPtr = cPtr
        
        BRPeerManagerSetCallbacks(cPtr, Unmanaged.passUnretained(self).toOpaque(),
        { (info) in // syncStarted
            guard let info = info else { return }
            Unmanaged<BRPeerManager>.fromOpaque(info).takeUnretainedValue().listener.syncStarted()
        },
        { (info) in // syncSucceeded
            guard let info = info else { return }
            Unmanaged<BRPeerManager>.fromOpaque(info).takeUnretainedValue().listener.syncSucceeded()
        },
        { (info, error) in // syncFailed
            guard let info = info else { return }
            let err = BRPeerManagerError.posixError(errorCode: error, description: String(cString: strerror(error)))
            Unmanaged<BRPeerManager>.fromOpaque(info).takeUnretainedValue().listener.syncFailed(err)
        },
        { (info) in // txStatusUpdate
            guard let info = info else { return }
            Unmanaged<BRPeerManager>.fromOpaque(info).takeUnretainedValue().listener.txStatusUpdate()
        },
        { (info, blocks, blocksCount) in // saveBlocks
            guard let info = info else { return }
            let blockRefs = [BRBlockRef?](UnsafeBufferPointer(start: blocks, count: blocksCount))
            Unmanaged<BRPeerManager>.fromOpaque(info).takeUnretainedValue().listener.saveBlocks(blockRefs)
        },
        { (info, peers, peersCount) in // savePeers
            guard let info = info else { return }
            let peerList = [BRPeer](UnsafeBufferPointer(start: peers, count: peersCount))
            Unmanaged<BRPeerManager>.fromOpaque(info).takeUnretainedValue().listener.savePeers(peerList)
        },
        { (info) -> Int32 in // networkIsReachable
            guard let info = info else { return 0 }
            return Unmanaged<BRPeerManager>.fromOpaque(info).takeUnretainedValue().listener.networkIsReachable() ? 1 : 0
        },
        nil) // threadCleanup
    }
    
    // true if currently connected to at least one peer
    var isConnected: Bool {
        return BRPeerManagerIsConnected(cPtr) != 0
    }
    
    // connect to bitcoin peer-to-peer network (also call this whenever networkIsReachable() status changes)
    func connect() {
        BRPeerManagerConnect(cPtr)
    }
    
    // disconnect from bitcoin peer-to-peer network
    func disconnect() {
        BRPeerManagerDisconnect(cPtr)
    }
    
    // rescans blocks and transactions after earliestKeyTime (a new random download peer is also selected due to the
    // possibility that a malicious node might lie by omitting transactions that match the bloom filter)
    func rescan() {
        BRPeerManagerRescan(cPtr)
    }
    
    // current proof-of-work verified best block height
    var lastBlockHeight: UInt32 {
        return BRPeerManagerLastBlockHeight(cPtr)
    }
    
    // the (unverified) best block height reported by connected peers
    var estimatedBlockHeight: UInt32 {
        return BRPeerManagerEstimatedBlockHeight(cPtr)
    }
    
    // current network sync progress from 0 to 1
    // startHeight is the block height of the most recent fully completed sync
    func syncProgress(fromStartHeight: UInt32) -> Double {
        return BRPeerManagerSyncProgress(cPtr, fromStartHeight)
    }
    
    // the number of currently connected peers
    var peerCount: Int {
        return BRPeerManagerPeerCount(cPtr)
    }
    
    // description of the peer most recently used to sync blockchain data
    var downloadPeerName: String {
        return String(cString: BRPeerManagerDownloadPeerName(cPtr))
    }
    
    // publishes tx to bitcoin network
    func publishTx(_ tx: BRTxRef, completion: @escaping (Bool, BRPeerManagerError?) -> ()) {
        BRPeerManagerPublishTx(cPtr, tx, Unmanaged.passRetained(CompletionWrapper(completion)).toOpaque())
        { (info, error) in
            guard let info = info else { return }
            guard error == 0 else {
                let err = BRPeerManagerError.posixError(errorCode: error, description: String(cString: strerror(error)))
                return Unmanaged<CompletionWrapper>.fromOpaque(info).takeRetainedValue().completion(false, err)
            }
            
            Unmanaged<CompletionWrapper>.fromOpaque(info).takeRetainedValue().completion(true, nil)
        }
    }
    
    // number of connected peers that have relayed the given unconfirmed transaction
    func relayCount(_ forTxHash: UInt256) -> Int {
        return BRPeerManagerRelayCount(cPtr, forTxHash)
    }
    
    deinit {
        BRPeerManagerDisconnect(cPtr)
        BRPeerManagerFree(cPtr)
    }
    
    private class CompletionWrapper {
        let completion: (Bool, BRPeerManagerError?) -> ()
        
        init(_ completion: @escaping (Bool, BRPeerManagerError?) -> ()) {
            self.completion = completion
        }
    }
}
