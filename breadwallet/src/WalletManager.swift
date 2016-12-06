//
//  WalletManager.swift
//  breadwallet
//
//  Created by Aaron Voisine on 10/13/16.
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
import SystemConfiguration
import BRCore
import CSQLite3


internal let SQLITE_STATIC = unsafeBitCast(0, to: sqlite3_destructor_type.self)
internal let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

enum WalletManagerError: Error {
    case sqliteError(errorCode: Int32)
}

extension NSNotification.Name {
    public static let WalletBalanceChangedNotification = NSNotification.Name("WalletBalanceChanged")
    public static let WalletTxStatusUpdateNotification = NSNotification.Name("WalletTxStatusUpdate")
    public static let WalletTxRejectedNotification = NSNotification.Name("WalletTxRejected")
    public static let WalletSyncStartedNotification = NSNotification.Name("WalletSyncStarted")
    public static let WalletSyncSucceededNotification = NSNotification.Name("WalletSyncSucceeded")
    public static let WalletSyncFailedNotification = NSNotification.Name("WalletSyncFailed")
}

typealias BRTxRef = UnsafeMutablePointer<BRTransaction>

extension BRAddress : CustomStringConvertible {
    public var description : String {
        return String(cString: UnsafeRawPointer([self.s]).assumingMemoryBound(to: CChar.self))
    }
}

extension BRTxInput {
    public var address : String {
        return String(cString: UnsafeRawPointer([self.address]).assumingMemoryBound(to: CChar.self))
    }

    public var script : [UInt8] {
        return [UInt8](UnsafeBufferPointer(start: self.script, count: self.scriptLen))
    }

    public var signature : [UInt8] {
        return [UInt8](UnsafeBufferPointer(start: self.signature, count: self.sigLen))
    }
}

extension BRTxOutput {
    public var address : String {
        return String(cString: UnsafeRawPointer([self.address]).assumingMemoryBound(to: CChar.self))
    }
    
    public var script : [UInt8] {
        return [UInt8](UnsafeBufferPointer(start: self.script, count: self.scriptLen))
    }
}

extension BRTransaction {
    public var inputs : [BRTxInput] {
        return [BRTxInput](UnsafeBufferPointer(start: self.inputs, count: self.inCount))
    }

    public var outputs : [BRTxOutput] {
        return [BRTxOutput](UnsafeBufferPointer(start: self.outputs, count: self.outCount))
    }
}

extension BRMasterPubKey : Equatable {
    public static func ==(_ lhs: BRMasterPubKey, _ rhs: BRMasterPubKey) -> Bool {
        return lhs.fingerPrint == rhs.fingerPrint && lhs.chainCode.u64 == rhs.chainCode.u64 && lhs.pubKey.0 == rhs.pubKey.0
    }
}

class BRWallet {
    @available(*, unavailable) init() {}
    
    public var ptr : OpaquePointer {
       return OpaquePointer(Unmanaged.passUnretained(self).toOpaque())
    }
    
    func transactions() -> [BRTxRef] {
        return []
    }
}

class BRPeerManager {
    @available(*, unavailable) init() {}

    public var ptr : OpaquePointer {
        return OpaquePointer(Unmanaged.passUnretained(self).toOpaque())
    }
}

// A WalletManger instance manages a single wallet, and that wallet's individual connection to the bitcoin network.
// After instantiating a WalletManager object, call BRPeerManagerConnect(myWalletManager.peerManager) to begin syncing.

class WalletManager : NSObject {
    typealias BRBlockRef = UnsafeMutablePointer<BRMerkleBlock>
    
    internal var didInitWallet = false
    internal let dbPath : String
    internal var db : OpaquePointer? = nil
    private var txEnt : Int32 = 0
    private var blockEnt : Int32 = 0
    private var peerEnt : Int32 = 0
    
    var masterPubKey = BRMasterPubKey()
    var earliestKeyTime : TimeInterval = 0
    
    lazy var wallet : BRWallet? = {
        var transactions = self.loadTransactions()
        guard let wallet = BRWalletNew(&transactions, transactions.count, self.masterPubKey) else {
            // stored transactions don't match masterPubKey
            #if !DEBUG
                do { try FileManager.default.removeItem(atPath: self.dbPath) } catch { }
            #endif
            abort()
        }
        
        BRWalletSetCallbacks(wallet, Unmanaged.passUnretained(self).toOpaque(),
        { (info, balance) in // balanceChanged
            DispatchQueue.main.async() {
                NotificationCenter.default.post(name: .WalletBalanceChangedNotification, object: nil,
                                                userInfo: ["balance": balance])
            }
        },
        { (info, tx) in // txAdded
            guard let wm = info?.assumingMemoryBound(to: WalletManager.self).pointee, let tx = tx else { return }
            
            wm.addTransaction(tx)
        },
        { (info, txHashes, txCount, blockHeight, timestamp) in // txUpdated
            guard let wm = info?.assumingMemoryBound(to: WalletManager.self).pointee else { return }
            
            wm.updateTransactions(txHashes: [UInt256](UnsafeBufferPointer(start: txHashes, count: txCount)),
                                  blockHeight: blockHeight, timestamp: timestamp)
        },
        { (info, txHash, notifyUser, recommendRescan) in // txDeleted
            guard let wm = info?.assumingMemoryBound(to: WalletManager.self).pointee else { return }
            
            wm.deleteTransaction(txHash)
            
            if notifyUser != 0 {
                DispatchQueue.main.async() {
                    NotificationCenter.default.post(name: .WalletTxRejectedNotification, object: nil,
                                                    userInfo: ["txHash": txHash,
                                                               "recommendRescan": (recommendRescan != 0)])
                }
            }
        })

        self.didInitWallet = true
        return Unmanaged<BRWallet>.fromOpaque(UnsafeRawPointer(wallet)).takeUnretainedValue()
    }()

    lazy var peerManager : BRPeerManager? = {
        guard let wallet = self.wallet else { return nil }
        var blocks = self.loadBlocks()
        var peers = self.loadPeers()
        guard let peerManager = BRPeerManagerNew(wallet.ptr, UInt32(self.earliestKeyTime + NSTimeIntervalSince1970),
                                                 &blocks, blocks.count, &peers, peers.count) else { return nil }
        
        BRPeerManagerSetCallbacks(peerManager, Unmanaged.passUnretained(self).toOpaque(),
        { (info) in // syncStarted
            DispatchQueue.main.async() {
                NotificationCenter.default.post(name: .WalletSyncStartedNotification, object: nil)
            }
        },
        { (info) in // syncSucceeded
            DispatchQueue.main.async() {
                NotificationCenter.default.post(name: .WalletSyncSucceededNotification, object: nil)
            }
        },
        { (info, error) in // syncFailed
            DispatchQueue.main.async() {
                NotificationCenter.default.post(name: .WalletSyncFailedNotification, object: nil,
                                                userInfo: ["errorCode": error,
                                                           "errorDescription": String(cString: strerror(error))])
            }
        },
        { (info) in // txStatusUpdate
            DispatchQueue.main.async() {
                NotificationCenter.default.post(name: .WalletTxStatusUpdateNotification, object: nil)
            }
        },
        { (info, blocks, blocksCount) in // saveBlocks
            guard let wm = info?.assumingMemoryBound(to: WalletManager.self).pointee else { return }
            
            wm.saveBlocks([BRBlockRef?](UnsafeBufferPointer(start: blocks, count: blocksCount)))
        },
        { (info, peers, peersCount) in // savePeers
            guard let wm = info?.assumingMemoryBound(to: WalletManager.self).pointee else { return }
            
            wm.savePeers([BRPeer](UnsafeBufferPointer(start: peers, count: peersCount)))
        },
        { (info) -> Int32 in // networkIsReachable
            guard let wm = info?.assumingMemoryBound(to: WalletManager.self).pointee else { return 0 }
            
            return wm.isNetworkReachable() ? 1 : 0
        },
        nil) // threadCleanup

        return Unmanaged<BRPeerManager>.fromOpaque(UnsafeRawPointer(peerManager)).takeUnretainedValue()
    }()
    
    init(masterPubKey : BRMasterPubKey, earliestKeyTime : TimeInterval, dbPath : String? = nil) throws {
        let dbPath = try dbPath ??
            FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil,
                                    create: false).appendingPathComponent("BreadWallet.sqlite").path
        
        self.masterPubKey = masterPubKey
        self.earliestKeyTime = earliestKeyTime
        self.dbPath = dbPath
        
        // open sqlite database
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            print(String(cString: sqlite3_errmsg(db)))

            #if DEBUG
                throw WalletManagerError.sqliteError(errorCode: sqlite3_errcode(db))
            #else
                try FileManager.default.removeItem(atPath: dbPath)
                
                if sqlite3_open(dbPath, &db) != SQLITE_OK {
                    print(String(cString: sqlite3_errmsg(db)))
                    throw WalletManagerError.sqliteError(errorCode: sqlite3_errcode(db))
                }
            #endif
        }
        
        // create tables and indexes (these are inherited from CoreData)

        // tx table
        sqlite3_exec(db, "create table if not exists ZBRTXMETADATAENTITY (" +
            "Z_PK integer primary key," +
            "Z_ENT integer," +
            "Z_OPT integer," +
            "ZTYPE integer," +
            "ZBLOB blob," +
            "ZTXHASH blob)", nil, nil, nil)
        sqlite3_exec(db, "create index if not exists ZBRTXMETADATAENTITY_ZTXHASH_INDEX " +
            "on ZBRTXMETADATAENTITY (ZTXHASH)", nil, nil, nil)
        sqlite3_exec(db, "create index if not exists ZBRTXMETADATAENTITY_ZTYPE_INDEX " +
            "on ZBRTXMETADATAENTITY (ZTYPE)", nil, nil, nil)
        
        if sqlite3_errcode(db) != SQLITE_OK {
            print(String(cString: sqlite3_errmsg(db)))
        }
        
        // blocks table
        sqlite3_exec(db, "create table if not exists ZBRMERKLEBLOCKENTITY (" +
            "Z_PK integer primary key," +
            "Z_ENT integer," +
            "Z_OPT integer," +
            "ZHEIGHT integer," +
            "ZNONCE integer," +
            "ZTARGET integer," +
            "ZTOTALTRANSACTIONS integer," +
            "ZVERSION integer," +
            "ZTIMESTAMP timestamp," +
            "ZBLOCKHASH blob," +
            "ZFLAGS blob," +
            "ZHASHES blob," +
            "ZMERKLEROOT blob," +
            "ZPREVBLOCK blob)", nil, nil, nil)
        sqlite3_exec(db, "create index if not exists ZBRMERKLEBLOCKENTITY_ZBLOCKHASH_INDEX " +
            "on ZBRMERKLEBLOCKENTITY (ZBLOCKHASH)", nil, nil, nil)
        sqlite3_exec(db, "create index if not exists ZBRMERKLEBLOCKENTITY_ZHEIGHT_INDEX " +
            "on ZBRMERKLEBLOCKENTITY (ZHEIGHT)", nil, nil, nil)
        sqlite3_exec(db, "create index if not exists ZBRMERKLEBLOCKENTITY_ZPREVBLOCK_INDEX " +
            "on ZBRMERKLEBLOCKENTITY (ZPREVBLOCK)", nil, nil, nil)
        
        if sqlite3_errcode(db) != SQLITE_OK {
            print(String(cString: sqlite3_errmsg(db)))
        }
        
        // peers table
        sqlite3_exec(db, "create table if not exists ZBRPEERENTITY (" +
            "Z_PK integer PRIMARY KEY," +
            "Z_ENT integer," +
            "Z_OPT integer," +
            "ZADDRESS integer," +
            "ZMISBEHAVIN integer," +
            "ZPORT integer," +
            "ZSERVICES integer," +
            "ZTIMESTAMP timestamp)", nil, nil, nil)
        sqlite3_exec(db, "create index if not exists ZBRPEERENTITY_ZADDRESS_INDEX on ZBRPEERENTITY (ZADDRESS)",
                     nil, nil, nil)
        sqlite3_exec(db, "create index if not exists ZBRPEERENTITY_ZMISBEHAVIN_INDEX on ZBRPEERENTITY (ZMISBEHAVIN)",
                     nil, nil, nil)
        sqlite3_exec(db, "create index if not exists ZBRPEERENTITY_ZPORT_INDEX on ZBRPEERENTITY (ZPORT)",
                     nil, nil, nil)
        sqlite3_exec(db, "create index if not exists ZBRPEERENTITY_ZTIMESTAMP_INDEX on ZBRPEERENTITY (ZTIMESTAMP)",
                     nil, nil, nil)
        
        if sqlite3_errcode(db) != SQLITE_OK {
            print(String(cString: sqlite3_errmsg(db)))
        }
        
        // primary keys
        sqlite3_exec(db, "create table if not exists Z_PRIMARYKEY (" +
            "Z_ENT INTEGER PRIMARY KEY," +
            "Z_NAME VARCHAR," +
            "Z_SUPER INTEGER," +
            "Z_MAX INTEGER)", nil, nil, nil)
        sqlite3_exec(db, "insert into Z_PRIMARYKEY (Z_ENT, Z_NAME, Z_SUPER, Z_MAX) " +
            "select 6, 'BRTxMetadataEntity', 0, 0 except" +
            "select 6, Z_NAME, 0, 0 from Z_PRIMARYKEY where Z_NAME = 'BRTxMetadataEntity'", nil, nil, nil)
        sqlite3_exec(db, "insert into Z_PRIMARYKEY (Z_ENT, Z_NAME, Z_SUPER, Z_MAX) " +
            "select 2, 'BRMerkleBlockEntity', 0, 0 except" +
            "select 2, Z_NAME, 0, 0 from Z_PRIMARYKEY where Z_NAME = 'BRMerkleBlockEntity'", nil, nil, nil)
        sqlite3_exec(db, "insert into Z_PRIMARYKEY (Z_ENT, Z_NAME, Z_SUPER, Z_MAX) " +
            "select 3, 'BRPeerEntity', 0, 0 except" +
            "select 3, Z_NAME, 0, 0 from Z_PRIMARYKEY where Z_NAME = 'BRPeerEntity'", nil, nil, nil)

        var sql : OpaquePointer? = nil

        sqlite3_prepare_v2(db, "select Z_ENT, Z_NAME from Z_PRIMARYKEY", -1, &sql, nil)
        defer { sqlite3_finalize(sql) }
        
        while sqlite3_step(sql) == SQLITE_ROW {
            let name = String(cString: sqlite3_column_text(sql, 1))
            
            if name == "BRTxMetadataEntity" { txEnt = sqlite3_column_int(sql, 0) }
            else if name == "BRTxMerkleBlockEntity" { blockEnt = sqlite3_column_int(sql, 0) }
            else if name == "BRPeerEntity" { peerEnt = sqlite3_column_int(sql, 0) }
        }
        
        if sqlite3_errcode(db) != SQLITE_OK {
            print(String(cString: sqlite3_errmsg(db)))
        }
    }
    
    private func loadTransactions() -> [BRTxRef?] {
        var transactions = [BRTxRef?]()
        var sql : OpaquePointer? = nil
        
        sqlite3_prepare_v2(db, "select ZBLOB from ZBRTXMETADATAENTITY where ZTYPE = 1", -1, &sql, nil)
        defer { sqlite3_finalize(sql) }
        
        while sqlite3_step(sql) == SQLITE_ROW {
            let len = Int(sqlite3_column_bytes(sql, 0))
            let buf = sqlite3_column_blob(sql, 0).assumingMemoryBound(to: UInt8.self)
            guard len >= MemoryLayout<UInt32>.size*2,
                let tx = BRTransactionParse(buf, len - MemoryLayout<UInt32>.size*2) else {
                return transactions
            }
                
            tx.pointee.blockHeight = UnsafeRawPointer(buf).load(fromByteOffset: len - MemoryLayout<UInt32>.size*2,
                                                                as: UInt32.self).littleEndian
            tx.pointee.timestamp = UnsafeRawPointer(buf).load(fromByteOffset: len - MemoryLayout<UInt32>.size,
                                                              as: UInt32.self).littleEndian
            transactions.append(tx)
        }
        
        if sqlite3_errcode(db) != SQLITE_OK {
            print(String(cString: sqlite3_errmsg(db)))
        }
        
        return transactions
    }
    
    private func addTransaction(_ tx : BRTxRef) {
        var buf = [UInt8](repeating: 0, count: BRTransactionSerialize(tx, nil, 0))
        let extra = [tx.pointee.blockHeight.littleEndian, tx.pointee.timestamp.littleEndian]
        
        BRTransactionSerialize(tx, &buf, buf.count)
        buf.append(contentsOf: UnsafeBufferPointer(start: UnsafeRawPointer(extra).assumingMemoryBound(to: UInt8.self),
                                                   count: MemoryLayout<UInt32>.size*2))
        sqlite3_exec(db, "begin exclusive", nil, nil, nil)

        var sql : OpaquePointer? = nil
        
        sqlite3_prepare_v2(db, "select Z_MAX from Z_PRIMARYKEY where Z_ENT = \(txEnt)", -1, &sql, nil)
        defer { sqlite3_finalize(sql) }
        
        guard sqlite3_step(sql) == SQLITE_ROW else {
            print(String(cString: sqlite3_errmsg(db)))
            sqlite3_exec(db, "rollback", nil, nil, nil)
            return
        }

        let pk = sqlite3_column_int(sql, 0)
        var sql2 : OpaquePointer? = nil
        
        sqlite3_prepare_v2(db, "insert or rollback into ZBRTXMETADATAENTITY " +
            "(Z_PK, Z_ENT, Z_OPT, ZTYPE, ZBLOB, ZTXHASH) " +
            "values (\(pk + 1), \(txEnt), 1, 1, ?, ?)", -1, &sql2, nil)
        defer { sqlite3_finalize(sql2) }
        sqlite3_bind_blob(sql2, 2, buf, Int32(buf.count), SQLITE_TRANSIENT)
        sqlite3_bind_blob(sql2, 3, [tx.pointee.txHash], Int32(MemoryLayout<UInt256>.size), SQLITE_TRANSIENT)

        guard sqlite3_step(sql2) == SQLITE_OK else {
            print(String(cString: sqlite3_errmsg(db)))
            return
        }
        
        sqlite3_exec(db, "update or rollback Z_PRIMARYKEY set Z_MAX = \(pk + 1) " +
            "where Z_ENT = \(txEnt) and Z_MAX = \(pk)", nil, nil, nil)
        
        guard sqlite3_errcode(db) == SQLITE_OK else {
            print(String(cString: sqlite3_errmsg(db)))
            return
        }
        
        sqlite3_exec(db, "commit", nil, nil, nil)
    }
    
    private func updateTransactions(txHashes : [UInt256], blockHeight : UInt32, timestamp : UInt32) {
        guard txHashes.count > 0 else { return }

        let extra = [blockHeight.littleEndian, timestamp.littleEndian]
        let extraBuf = UnsafeBufferPointer(start: UnsafeRawPointer(extra).assumingMemoryBound(to: UInt8.self),
                                           count: MemoryLayout<UInt32>.size*2)
        var sql : OpaquePointer? = nil, sql2 : OpaquePointer? = nil
        
        sqlite3_prepare_v2(db, "select ZTXHASH, ZBLOB from ZBRTXMETADATAENTITY where ZTYPE = 1 and " +
            "ZTXHASH in (" + String(repeating: "?, ", count: txHashes.count - 1) + "?)", -1, &sql, nil)
        defer { sqlite3_finalize(sql) }
        
        for i in 0..<txHashes.count {
            sqlite3_bind_blob(sql, i + 1, UnsafePointer(txHashes) + i, Int32(MemoryLayout<UInt256>.size),
                              SQLITE_TRANSIENT)
        }
        
        sqlite3_prepare_v2(db, "update ZBRTXMETADATAENTITY set ZBLOB = ? where ZTXHASH = ?", -1, &sql2, nil)
        defer { sqlite3_finalize(sql2) }
        
        while sqlite3_step(sql) == SQLITE_ROW {
            let hash = sqlite3_column_blob(sql, 0)
            let buf = sqlite3_column_blob(sql, 1).assumingMemoryBound(to: UInt8.self)
            var blob = [UInt8](UnsafeBufferPointer(start: buf, count: Int(sqlite3_column_bytes(sql, 1))))
                    
            if blob.count > extraBuf.count {
                blob.replaceSubrange(blob.count - extraBuf.count..<blob.count, with: extraBuf)
                sqlite3_bind_blob(sql2, 1, blob, Int32(blob.count), SQLITE_TRANSIENT)
                sqlite3_bind_blob(sql2, 2, hash, Int32(MemoryLayout<UInt256>.size), SQLITE_TRANSIENT)
                sqlite3_step(sql2)
                sqlite3_reset(sql2)
            }
        }
        
        if sqlite3_errcode(db) != SQLITE_OK {
            print(String(cString: sqlite3_errmsg(db)))
        }
    }
    
    private func deleteTransaction(_ txHash : UInt256) {
        var sql : OpaquePointer? = nil
        
        sqlite3_prepare_v2(db, "delete from ZBRTXMETADATAENTITY where ZTYPE = 1 and ZTXHASH = ?", -1, &sql, nil)
        defer { sqlite3_finalize(sql) }
        sqlite3_bind_blob(sql, 1, [txHash], Int32(MemoryLayout<UInt256>.size), SQLITE_TRANSIENT)

        guard sqlite3_step(sql) == SQLITE_OK else {
            print(String(cString: sqlite3_errmsg(db)))
            return
        }
    }

    private func loadBlocks() -> [BRBlockRef?] {
        var blocks = [BRBlockRef?]()
        var sql : OpaquePointer? = nil
        
        sqlite3_prepare_v2(db, "select ZHEIGHT, ZNONCE, ZTARGET, ZTOTALTRANSACTIONS, ZVERSION, ZTIMESTAMP, " +
            "ZBLOCKHASH, ZFLAGS, ZHASHES, ZMERKLEROOT, ZPREVBLOCK from ZBRMERKLEBLOCKENTITY", -1, &sql, nil)
        defer { sqlite3_finalize(sql) }
        
        while sqlite3_step(sql) == SQLITE_ROW {
            guard let b = BRMerkleBlockNew() else { return blocks }
            
            b.pointee.height = UInt32(bitPattern: sqlite3_column_int(sql, 0))
            b.pointee.nonce = UInt32(bitPattern: sqlite3_column_int(sql, 1))
            b.pointee.target = UInt32(bitPattern: sqlite3_column_int(sql, 2))
            b.pointee.totalTx = UInt32(bitPattern: sqlite3_column_int(sql, 3))
            b.pointee.version = UInt32(bitPattern: sqlite3_column_int(sql, 4))
            b.pointee.timestamp = UInt32(bitPattern: sqlite3_column_int(sql, 5))
            b.pointee.blockHash = sqlite3_column_blob(sql, 6).assumingMemoryBound(to: UInt256.self).pointee
            
            let flags = sqlite3_column_blob(sql, 7).assumingMemoryBound(to: UInt8.self)
            let flagsLen = Int(sqlite3_column_bytes(sql, 7))
            let hashes = sqlite3_column_blob(sql, 8).assumingMemoryBound(to: UInt256.self)
            let hashesCount = Int(sqlite3_column_bytes(sql, 8))/MemoryLayout<UInt256>.size
            
            BRMerkleBlockSetTxHashes(b, hashes, hashesCount, flags, flagsLen)
            b.pointee.merkleRoot = sqlite3_column_blob(sql, 9).assumingMemoryBound(to: UInt256.self).pointee
            b.pointee.prevBlock = sqlite3_column_blob(sql, 10).assumingMemoryBound(to: UInt256.self).pointee
            blocks.append(b)
        }
    
        if sqlite3_errcode(db) != SQLITE_OK {
            print(String(cString: sqlite3_errmsg(db)))
        }

        return blocks
    }
    
    private func saveBlocks(_ blocks : [BRBlockRef?]) {
        var pk : Int32 = 0

        sqlite3_exec(db, "begin exclusive", nil, nil, nil)
        
        if blocks.count > 1 {
            sqlite3_exec(db, "delete from ZBRMERKLEBLOCKENTITY", nil, nil, nil)
        }
        else {
            var sql : OpaquePointer? = nil
        
            sqlite3_prepare_v2(db, "select Z_MAX from Z_PRIMARYKEY where Z_ENT = \(blockEnt)", -1, &sql, nil)
            defer { sqlite3_finalize(sql) }

            guard sqlite3_step(sql) == SQLITE_ROW else {
                print(String(cString: sqlite3_errmsg(db)))
                sqlite3_exec(db, "rollback", nil, nil, nil)
                return
            }

            pk = sqlite3_column_int(sql, 0)
        }

        var sql2 : OpaquePointer? = nil

        sqlite3_prepare_v2(db, "insert or rollback into ZBRMERKLEBLOCKENTITY (Z_PK, Z_ENT, Z_OPT, ZHEIGHT, ZNONCE, " +
            "ZTARGET, ZTOTALTRANSACTIONS, ZVERSION, ZTIMESTAMP, ZBLOCKHASH, ZFLAGS, ZHASHES, ZMERKLEROOT, " +
            "ZPREVBLOCK) values (?, \(blockEnt), 1, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", -1, &sql2, nil)
        defer { sqlite3_finalize(sql2) }
        
        for b in blocks {
            guard let b = b else {
                sqlite3_exec(db, "rollback", nil, nil, nil)
                return
            }
            
            pk = pk + 1
            sqlite3_bind_int(sql2, 1, pk)
            sqlite3_bind_int(sql2, 2, Int32(bitPattern: b.pointee.height))
            sqlite3_bind_int(sql2, 3, Int32(bitPattern: b.pointee.nonce))
            sqlite3_bind_int(sql2, 4, Int32(bitPattern: b.pointee.target))
            sqlite3_bind_int(sql2, 5, Int32(bitPattern: b.pointee.totalTx))
            sqlite3_bind_int(sql2, 6, Int32(bitPattern: b.pointee.version))
            sqlite3_bind_int(sql2, 7, Int32(bitPattern: b.pointee.timestamp))
            sqlite3_bind_blob(sql2, 8, [b.pointee.blockHash], Int32(MemoryLayout<UInt256>.size), SQLITE_TRANSIENT)
            sqlite3_bind_blob(sql2, 9, [b.pointee.flags], Int32(b.pointee.flagsLen), SQLITE_TRANSIENT)
            sqlite3_bind_blob(sql2, 10, [b.pointee.hashes], Int32(MemoryLayout<UInt256>.size*b.pointee.hashesCount),
                              SQLITE_TRANSIENT)
            sqlite3_bind_blob(sql2, 11, [b.pointee.merkleRoot], Int32(MemoryLayout<UInt256>.size), SQLITE_TRANSIENT)
            sqlite3_bind_blob(sql2, 12, [b.pointee.prevBlock], Int32(MemoryLayout<UInt256>.size), SQLITE_TRANSIENT)
            
            guard sqlite3_step(sql2) == SQLITE_OK else {
                print(String(cString: sqlite3_errmsg(db)))
                return
            }
            
            sqlite3_reset(sql2)
        }
        
        sqlite3_exec(db, "update or rollback Z_PRIMARYKEY set Z_MAX = \(pk) where Z_ENT = \(blockEnt)", nil, nil, nil)

        guard sqlite3_errcode(db) == SQLITE_OK else {
            print(String(cString: sqlite3_errmsg(db)))
            return
        }

        sqlite3_exec(db, "commit", nil, nil, nil)
    }
    
    private func loadPeers() -> [BRPeer] {
        var peers = [BRPeer]()
        var sql : OpaquePointer? = nil
        
        sqlite3_prepare_v2(db, "select ZADDRESS, ZPORT, ZSERVICES, ZTIMESTAMP from ZBRPEERENTITY", -1, &sql, nil)
        defer { sqlite3_finalize(sql) }
        
        while sqlite3_step(sql) == SQLITE_ROW {
            var p = BRPeer()
                
            p.address = UInt128(u32: (0, 0, UInt32(0xffff).bigEndian,
                                      UInt32(bitPattern: sqlite3_column_int(sql, 0)).bigEndian))
            p.port = UInt16(truncatingBitPattern: sqlite3_column_int(sql, 1))
            p.services = UInt64(bitPattern: sqlite3_column_int64(sql, 2))
            p.timestamp = UInt64(bitPattern: sqlite3_column_int64(sql, 3))
            peers.append(p)
        }
        
        if sqlite3_errcode(db) != SQLITE_OK {
            print(String(cString: sqlite3_errmsg(db)))
        }

        return peers
    }
    
    private func savePeers(_ peers : [BRPeer]) {
        var pk : Int32 = 0
        
        sqlite3_exec(db, "begin exclusive", nil, nil, nil)

        if peers.count > 1 {
            sqlite3_exec(db, "delete from ZBRPEERENTITY", nil, nil, nil)
        }
        else {
            var sql : OpaquePointer? = nil
            
            sqlite3_prepare_v2(db, "select Z_MAX from Z_PRIMARYKEY where Z_ENT = \(peerEnt)", -1, &sql, nil)
            defer { sqlite3_finalize(sql) }
            
            guard sqlite3_step(sql) == SQLITE_ROW else {
                print(String(cString: sqlite3_errmsg(db)))
                sqlite3_exec(db, "rollback", nil, nil, nil)
                return
            }

            pk = sqlite3_column_int(sql, 0)
        }
        
        var sql2 : OpaquePointer? = nil
        
        sqlite3_prepare_v2(db, "insert or rollback into ZBRPEERENTITY " +
            "(Z_PK, Z_ENT, Z_OPT, ZADDRESS, ZMISBEHAVIN, ZPORT, ZSERVICES, ZTIMESTAMP) " +
            "values (?, \(peerEnt), 1, ?, 0, ?, ?, ?)", -1, &sql2, nil)
        defer { sqlite3_finalize(sql2) }

        for p in peers {
            pk = pk + 1
            sqlite3_bind_int(sql2, 1, pk)
            sqlite3_bind_int(sql2, 2, Int32(bitPattern: p.address.u32.3))
            sqlite3_bind_int(sql2, 3, Int32(p.port))
            sqlite3_bind_int64(sql2, 4, Int64(bitPattern: p.services))
            sqlite3_bind_int64(sql2, 5, Int64(bitPattern: p.timestamp))

            guard sqlite3_step(sql2) == SQLITE_OK else {
                print(String(cString: sqlite3_errmsg(db)))
                return
            }

            sqlite3_reset(sql2)
        }
        
        sqlite3_exec(db, "update or rollback Z_PRIMARYKEY set Z_MAX = \(pk) where Z_ENT = \(peerEnt)", nil, nil, nil)
        
        guard sqlite3_errcode(db) == SQLITE_OK else {
            print(String(cString: sqlite3_errmsg(db)))
            return
        }

        sqlite3_exec(db, "commit", nil, nil, nil)
    }
    
    private func isNetworkReachable() -> Bool {
        var flags : SCNetworkReachabilityFlags = []
        var zeroAddress = sockaddr()
        
        zeroAddress.sa_len = UInt8(MemoryLayout<sockaddr>.size)
        zeroAddress.sa_family = sa_family_t(AF_INET)
        
        guard let reachability = SCNetworkReachabilityCreateWithAddress(nil, &zeroAddress) else { return false }
        
        if !SCNetworkReachabilityGetFlags(reachability, &flags) {
            return false
        }
        
        return flags.contains(.reachable) && !flags.contains(.connectionRequired)
        
        // TODO: XXX call BRPeerManagerConnect() whenever network reachability status changes
    }
    
    deinit {
        if didInitWallet {
            if peerManager != nil { BRPeerManagerDisconnect(peerManager?.ptr) }
            if peerManager != nil { BRPeerManagerFree(peerManager?.ptr) }
            if wallet != nil { BRWalletFree(wallet?.ptr) }
        }
        
        if db != nil { sqlite3_close(db) }
    }
}
