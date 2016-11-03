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

extension NSNotification.Name {
    public static let WalletBalanceChangedNotification = NSNotification.Name("WalletBalanceChanged")
    public static let WalletTxStatusUpdateNotification = NSNotification.Name("WalletTxStatusUpdate")
    public static let WalletTxRejectedNotification = NSNotification.Name("WalletTxRejected")
    public static let WalletSyncStartedNotification = NSNotification.Name("WalletSyncStarted")
    public static let WalletSyncSucceededNotification = NSNotification.Name("WalletSyncSucceeded")
    public static let WalletSyncFailedNotification = NSNotification.Name("WalletSyncFailed")
}

extension BRAddress {
    func str() -> String {
        return String(cString: UnsafeRawPointer([self.s]).assumingMemoryBound(to: CChar.self))
    }
}

extension BRTxInput {
    func addressStr() -> String {
        return String(cString: UnsafeRawPointer([self.address]).assumingMemoryBound(to: CChar.self))
    }
}

extension BRTxOutput {
    func addressStr() -> String {
        return String(cString: UnsafeRawPointer([self.address]).assumingMemoryBound(to: CChar.self))
    }    
}

extension BRTransaction {
    func inputArray() -> [BRTxInput] {
        return [BRTxInput](UnsafeBufferPointer(start: self.inputs, count: self.inCount))
    }

    func outputArray() -> [BRTxOutput] {
        return [BRTxOutput](UnsafeBufferPointer(start: self.outputs, count: self.outCount))
    }
}

// A WalletManger instance manages a single wallet, and that wallet's individual connection to the bitcoin network.
// After instantiating a WalletManager object, call BRPeerManagerConnect(myWalletManager.peerManager) to begin syncing.

class WalletManager : NSObject {
    private var db: OpaquePointer? = nil
    private var txEnt: Int32 = 0
    private var blockEnt: Int32 = 0
    private var peerEnt: Int32 = 0

    var peerManager: OpaquePointer? = nil
    var wallet: OpaquePointer? = nil
    
    convenience init (masterPubKey: BRMasterPubKey, earliestKeyTime: TimeInterval) {
        let dbURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil,
                                                 create: false).appendingPathComponent("BreadWallet.sqlite")
        
        self.init(masterPubKey: masterPubKey, earliestKeyTime: earliestKeyTime, dbPath: dbURL.path)
    }
    
    init (masterPubKey: BRMasterPubKey, earliestKeyTime: TimeInterval, dbPath: String) {
        super.init()
        
        // open sqlite database
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            print("error opening:", dbPath)
        }

        // setup tables and indexes
        setupDb()
        
        // instantiate wallet
        var transactions = loadTransactions()
        wallet = BRWalletNew(&transactions, transactions.count, masterPubKey)

        // instantiate peerManager
        var blocks = loadBlocks()
        var peers = loadPeers()
        peerManager = BRPeerManagerNew(wallet, UInt32(earliestKeyTime + NSTimeIntervalSince1970), &blocks, blocks.count,
                                       &peers, peers.count);

        // setup wallet and peerManager callbacks
        let info = Unmanaged.passUnretained(self).toOpaque()

        BRWalletSetCallbacks(wallet, info,
            { (info, balance) in // balanceChanged
                DispatchQueue.main.async() {
                    NotificationCenter.default.post(name: .WalletBalanceChangedNotification, object: nil,
                                                    userInfo: ["balance": balance])
                }
            },
            { (info, tx) in // txAdded
                let wm : WalletManager = (info?.assumingMemoryBound(to: WalletManager.self).pointee)!
                wm.addTransaction(tx: tx!)
            },
            { (info, txHashes, txCount, blockHeight, timestamp) in // txUpdated
                let wm : WalletManager = (info?.assumingMemoryBound(to: WalletManager.self).pointee)!
                
                if (txCount > 0) {
                    wm.updateTransactions(txHashes: [UInt256](UnsafeBufferPointer(start: txHashes, count: txCount)),
                                          blockHeight: blockHeight, timestamp: timestamp)
                }
            },
            { (info, txHash, notifyUser, recommendRescan) in // txDeleted
                let wm : WalletManager = (info?.assumingMemoryBound(to: WalletManager.self).pointee)!
                wm.deleteTransaction(txHash: txHash)

                if (notifyUser != 0) {
                    DispatchQueue.main.async() {
                        NotificationCenter.default.post(name: .WalletTxRejectedNotification, object: nil,
                                                        userInfo: ["txHash": txHash,
                                                                   "recommendRescan": (recommendRescan != 0)])
                    }
                }
            }
        )

        BRPeerManagerSetCallbacks(peerManager, info,
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
                let wm : WalletManager = (info?.assumingMemoryBound(to: WalletManager.self).pointee)!
                wm.saveBlocks(blocks: [UnsafeMutablePointer<BRMerkleBlock>?](UnsafeBufferPointer(start: blocks,
                                                                                                 count: blocksCount)))
            },
            { (info, peers, peersCount) in // savePeers
                let wm : WalletManager = (info?.assumingMemoryBound(to: WalletManager.self).pointee)!
                wm.savePeers(peers: [BRPeer](UnsafeBufferPointer(start: peers, count: peersCount)))
            },
            { (info) -> Int32 in // networkIsReachable
                let wm : WalletManager = (info?.assumingMemoryBound(to: WalletManager.self).pointee)!
                return wm.isNetworkReachable() ? 1 : 0
            },
            nil // threadCleanup
        )
    }
    
    // create tables and indexes (these are inherited from CoreData)
    private func setupDb() {
        var sql: OpaquePointer? = nil
        var r: Int32
        
        // tx table
        r = sqlite3_exec(db, "create table if not exists ZBRTXMETADATAENTITY (" +
            "Z_PK integer primary key," +
            "Z_ENT integer," +
            "Z_OPT integer," +
            "ZTYPE integer," +
            "ZBLOB blob," +
            "ZTXHASH blob)", nil, nil, nil)
        if r == SQLITE_OK {
            r = sqlite3_exec(db, "create index if not exists ZBRTXMETADATAENTITY_ZTXHASH_INDEX " +
                "on ZBRTXMETADATAENTITY (ZTXHASH)", nil, nil, nil)
        }
        if r == SQLITE_OK {
            r = sqlite3_exec(db, "create index if not exists ZBRTXMETADATAENTITY_ZTYPE_INDEX " +
                "on ZBRTXMETADATAENTITY (ZTYPE)", nil, nil, nil)
        }
        if r != SQLITE_OK { print(String(cString: sqlite3_errmsg(db))) }
        
        // blocks table
        r = sqlite3_exec(db, "create table if not exists ZBRMERKLEBLOCKENTITY (" +
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
        if r == SQLITE_OK {
            r = sqlite3_exec(db, "create index if not exists ZBRMERKLEBLOCKENTITY_ZBLOCKHASH_INDEX " +
                "on ZBRMERKLEBLOCKENTITY (ZBLOCKHASH)", nil, nil, nil)
        }
        if r == SQLITE_OK {
            r = sqlite3_exec(db, "create index if not exists ZBRMERKLEBLOCKENTITY_ZHEIGHT_INDEX " +
                "on ZBRMERKLEBLOCKENTITY (ZHEIGHT)", nil, nil, nil)
        }
        if r == SQLITE_OK {
            r = sqlite3_exec(db, "create index if not exists ZBRMERKLEBLOCKENTITY_ZPREVBLOCK_INDEX " +
                "on ZBRMERKLEBLOCKENTITY (ZPREVBLOCK)", nil, nil, nil)
        }
        if r != SQLITE_OK { print(String(cString: sqlite3_errmsg(db))) }
        
        // peers table
        r = sqlite3_exec(db, "create table if not exists ZBRPEERENTITY (" +
            "Z_PK integer PRIMARY KEY," +
            "Z_ENT integer," +
            "Z_OPT integer," +
            "ZADDRESS integer," +
            "ZMISBEHAVIN integer," +
            "ZPORT integer," +
            "ZSERVICES integer," +
            "ZTIMESTAMP timestamp)", nil, nil, nil)
        if r == SQLITE_OK {
            r = sqlite3_exec(db, "create index if not exists ZBRPEERENTITY_ZADDRESS_INDEX on ZBRPEERENTITY (ZADDRESS)",
                             nil, nil, nil)
        }
        if r == SQLITE_OK {
            r = sqlite3_exec(db, "create index if not exists ZBRPEERENTITY_ZMISBEHAVIN_INDEX " +
                "on ZBRPEERENTITY (ZMISBEHAVIN)", nil, nil, nil)
        }
        if r == SQLITE_OK {
            r = sqlite3_exec(db, "create index if not exists ZBRPEERENTITY_ZPORT_INDEX on ZBRPEERENTITY (ZPORT)",
                             nil, nil, nil)
        }
        if r == SQLITE_OK {
            r = sqlite3_exec(db, "create index if not exists ZBRPEERENTITY_ZTIMESTAMP_INDEX " +
                "on ZBRPEERENTITY (ZTIMESTAMP)", nil, nil, nil)
        }
        if r != SQLITE_OK { print(String(cString: sqlite3_errmsg(db))) }

        // primary keys
        r = sqlite3_exec(db, "create table if not exists Z_PRIMARYKEY (" +
            "Z_ENT INTEGER PRIMARY KEY," +
            "Z_NAME VARCHAR," +
            "Z_SUPER INTEGER," +
            "Z_MAX INTEGER)", nil, nil, nil)
        if r == SQLITE_OK {
            r = sqlite3_exec(db, "insert into Z_PRIMARYKEY (Z_ENT, Z_NAME, Z_SUPER, Z_MAX) " +
                "select 6, 'BRTxMetadataEntity', 0, 0 except" +
                "select 6, Z_NAME, 0, 0 from Z_PRIMARYKEY where Z_NAME = 'BRTxMetadataEntity'", nil, nil, nil)
        }
        if r == SQLITE_OK {
            r = sqlite3_exec(db, "insert into Z_PRIMARYKEY (Z_ENT, Z_NAME, Z_SUPER, Z_MAX) " +
                "select 2, 'BRMerkleBlockEntity', 0, 0 except" +
                "select 2, Z_NAME, 0, 0 from Z_PRIMARYKEY where Z_NAME = 'BRMerkleBlockEntity'", nil, nil, nil)
        }
        if r == SQLITE_OK {
            r = sqlite3_exec(db, "insert into Z_PRIMARYKEY (Z_ENT, Z_NAME, Z_SUPER, Z_MAX) " +
                "select 3, 'BRPeerEntity', 0, 0 except" +
                "select 3, Z_NAME, 0, 0 from Z_PRIMARYKEY where Z_NAME = 'BRPeerEntity'", nil, nil, nil)
        }
        if r == SQLITE_OK { r = sqlite3_prepare_v2(db, "select Z_ENT, Z_NAME from Z_PRIMARYKEY", -1, &sql, nil) }
        if r == SQLITE_OK { r = sqlite3_step(sql) }
        
        while r == SQLITE_ROW {
            let name = String(cString: sqlite3_column_text(sql, 1))
            
            if name == "BRTxMetadataEntity" { txEnt = sqlite3_column_int(sql, 0) }
            else if name == "BRTxMerkleBlockEntity" { blockEnt = sqlite3_column_int(sql, 0) }
            else if name == "BRPeerEntity" { peerEnt = sqlite3_column_int(sql, 0) }
            r = sqlite3_step(sql)
        }
        
        if r == SQLITE_DONE { r = sqlite3_finalize(sql) }
        if r != SQLITE_OK { print(String(cString: sqlite3_errmsg(db))) }
    }
    
    private func loadTransactions() -> [UnsafeMutablePointer<BRTransaction>?] {
        var sql: OpaquePointer? = nil
        var transactions = [UnsafeMutablePointer<BRTransaction>?]()
        var r: Int32

        r = sqlite3_prepare_v2(db, "select ZBLOB from ZBRTXMETADATAENTITY where ZTYPE = 1", -1, &sql, nil)
        if r == SQLITE_OK { r = sqlite3_step(sql) }
        
        while r == SQLITE_ROW {
            let buf = sqlite3_column_blob(sql, 0)
            let len = Int(sqlite3_column_bytes(sql, 0))
            let tx = BRTransactionParse(buf?.assumingMemoryBound(to: UInt8.self), len - MemoryLayout<UInt32>.size*2)
            
            tx?.pointee.blockHeight = (buf?.load(fromByteOffset: len - MemoryLayout<UInt32>.size*2,
                                                 as: UInt32.self).littleEndian)!
            tx?.pointee.timestamp = (buf?.load(fromByteOffset: len - MemoryLayout<UInt32>.size,
                                               as: UInt32.self).littleEndian)!
            transactions.append(tx)
            r = sqlite3_step(sql)
        }
        
        if r == SQLITE_DONE { r = sqlite3_finalize(sql) }
        if r != SQLITE_OK { print(String(cString: sqlite3_errmsg(db))) }
        return transactions
    }
    
    private func addTransaction(tx: UnsafeMutablePointer<BRTransaction>) {
        var sql: OpaquePointer? = nil
        var buf = [UInt8](repeating: 0, count: BRTransactionSerialize(tx, nil, 0))
        let extra = [tx.pointee.blockHeight.littleEndian, tx.pointee.timestamp.littleEndian]
        var r: Int32
        var pk: Int32 = 0
        
        BRTransactionSerialize(tx, &buf, buf.count)
        buf.append(contentsOf: UnsafeBufferPointer(start: UnsafeRawPointer(extra).assumingMemoryBound(to: UInt8.self),
                                                   count: MemoryLayout<UInt32>.size*2))
        
        r = sqlite3_exec(db, "begin exclusive", nil, nil, nil)
        if r == SQLITE_OK {
            r = sqlite3_prepare_v2(db, "select Z_MAX from Z_PRIMARYKEY where Z_ENT = \(txEnt)", -1, &sql, nil)
        }
        if r == SQLITE_OK { r = sqlite3_step(sql) }
        if r == SQLITE_ROW {
            pk = sqlite3_column_int(sql, 0)
            r = sqlite3_finalize(sql)
        }
        if r == SQLITE_OK {
            r = sqlite3_prepare_v2(db, "insert into ZBRTXMETADATAENTITY (Z_PK, Z_ENT, Z_OPT, ZTYPE, ZBLOB, ZTXHASH) " +
                "values (\(pk + 1), \(txEnt), 1, 1, ?, ?)", -1, &sql, nil)
        }
        if r == SQLITE_OK { r = sqlite3_bind_blob(sql, 2, buf, Int32(buf.count), SQLITE_TRANSIENT) }
        if r == SQLITE_OK {
            r = sqlite3_bind_blob(sql, 3, [tx.pointee.txHash], Int32(MemoryLayout<UInt256>.size), SQLITE_TRANSIENT)
        }
        if r == SQLITE_OK { r = sqlite3_step(sql) }
        if r == SQLITE_DONE {
            r = sqlite3_exec(db, "update or fail Z_PRIMARYKEY set Z_MAX = \(pk + 1) " +
                "where Z_ENT = \(txEnt) and Z_MAX = \(pk)", nil, nil, nil)
        }
        if r == SQLITE_OK { r = sqlite3_exec(db, "commit", nil, nil, nil) }
        if r == SQLITE_OK { r = sqlite3_finalize(sql) }
        if r != SQLITE_OK { print(String(cString: sqlite3_errmsg(db))) }
    }
    
    private func updateTransactions(txHashes: [UInt256], blockHeight: UInt32, timestamp: UInt32) {
        var sql: OpaquePointer? = nil
        var sql2: OpaquePointer? = nil
        let extra = [blockHeight.littleEndian, timestamp.littleEndian]
        let extraBuf = UnsafeBufferPointer(start: UnsafeRawPointer(extra).assumingMemoryBound(to: UInt8.self),
                                           count: MemoryLayout<UInt32>.size*2)
        var r: Int32
        
        r = sqlite3_prepare_v2(db, "update or fail ZBRTXMETADATAENTITY set ZBLOB = ? where ZTXHASH = ?", -1, &sql2, nil)
        
        if r == SQLITE_OK {
            r = sqlite3_prepare_v2(db, "select ZTXHASH, ZBLOB from ZBRTXMETADATAENTITY where ZTYPE = 1 and " +
                "ZTXHASH in (" + String(repeating: "?, ", count: txHashes.count - 1) + "?)", -1, &sql, nil)
        }
        
        for i in 0..<txHashes.count {
            if r == SQLITE_OK {
                r = sqlite3_bind_blob(sql2, i + 1, UnsafePointer(txHashes).advanced(by: i),
                                      Int32(MemoryLayout<UInt256>.size), SQLITE_TRANSIENT)
            }
        }
        
        if r == SQLITE_OK { r = sqlite3_step(sql) }

        while r == SQLITE_ROW {
            let hash = sqlite3_column_blob(sql, 0)
            let buf = sqlite3_column_blob(sql, 1)?.assumingMemoryBound(to: UInt8.self)
            var blob = [UInt8](UnsafeBufferPointer(start: buf, count: Int(sqlite3_column_bytes(sql, 1))))

            if blob.count > extraBuf.count {
                blob.replaceSubrange(blob.count - extraBuf.count..<blob.count, with: extraBuf)
                r = sqlite3_bind_blob(sql2, 1, blob, Int32(blob.count), SQLITE_TRANSIENT)

                if r == SQLITE_OK {
                    r = sqlite3_bind_blob(sql2, 2, hash, Int32(MemoryLayout<UInt256>.size), SQLITE_TRANSIENT)
                }
                if r == SQLITE_OK { r = sqlite3_step(sql2) }
                if r == SQLITE_DONE { r = sqlite3_reset(sql2) }
            }
            
            if r == SQLITE_ROW || r == SQLITE_OK { r = sqlite3_step(sql) }
        }

        if r == SQLITE_DONE { r = sqlite3_finalize(sql) }
        if r == SQLITE_OK { r = sqlite3_finalize(sql2) }
        if r != SQLITE_OK { print(String(cString: sqlite3_errmsg(db))) }
    }
    
    private func deleteTransaction(txHash: UInt256) {
        var sql: OpaquePointer? = nil
        var r: Int32
        
        r = sqlite3_prepare_v2(db, "delete from ZBRTXMETADATAENTITY where ZTYPE = 1 and ZTXHASH = ?", -1, &sql, nil)

        if r == SQLITE_OK {
            r = sqlite3_bind_blob(sql, 1, [txHash], Int32(MemoryLayout<UInt256>.size), SQLITE_TRANSIENT)
        }
        if r == SQLITE_OK { r = sqlite3_step(sql) }
        if r == SQLITE_DONE { r = sqlite3_finalize(sql) }
        if r != SQLITE_OK { print(String(cString: sqlite3_errmsg(db))) }
    }

    private func loadBlocks() -> [UnsafeMutablePointer<BRMerkleBlock>?] {
        var sql: OpaquePointer? = nil
        var blocks = [UnsafeMutablePointer<BRMerkleBlock>?]()
        var r: Int32
        
        r = sqlite3_prepare_v2(db, "select ZHEIGHT, ZNONCE, ZTARGET, ZTOTALTRANSACTIONS, ZVERSION, ZTIMESTAMP, " +
            "ZBLOCKHASH, ZFLAGS, ZHASHES, ZMERKLEROOT, ZPREVBLOCK from ZBRMERKLEBLOCKENTITY", -1, &sql, nil)
        if r == SQLITE_OK { r = sqlite3_step(sql) }
        
        while r == SQLITE_ROW {
            let block = BRMerkleBlockNew()
            
            block?.pointee.height = UInt32(bitPattern: sqlite3_column_int(sql, 0))
            block?.pointee.nonce = UInt32(bitPattern: sqlite3_column_int(sql, 1))
            block?.pointee.target = UInt32(bitPattern: sqlite3_column_int(sql, 2))
            block?.pointee.totalTx = UInt32(bitPattern: sqlite3_column_int(sql, 3))
            block?.pointee.version = UInt32(bitPattern: sqlite3_column_int(sql, 4))
            block?.pointee.timestamp = UInt32(bitPattern: sqlite3_column_int(sql, 5))
            block?.pointee.blockHash = (sqlite3_column_blob(sql, 6)?.assumingMemoryBound(to: UInt256.self).pointee)!
            
            let flags = sqlite3_column_blob(sql, 7)?.assumingMemoryBound(to: UInt8.self)
            let flagsLen = Int(sqlite3_column_bytes(sql, 7))
            let hashes = sqlite3_column_blob(sql, 8)?.assumingMemoryBound(to: UInt256.self)
            let hashesCount = Int(sqlite3_column_bytes(sql, 8))/MemoryLayout<UInt256>.size
            
            BRMerkleBlockSetTxHashes(block, hashes, hashesCount, flags, flagsLen)
            block?.pointee.merkleRoot = (sqlite3_column_blob(sql, 9)?.assumingMemoryBound(to: UInt256.self).pointee)!
            block?.pointee.prevBlock = (sqlite3_column_blob(sql, 10)?.assumingMemoryBound(to: UInt256.self).pointee)!
            blocks.append(block)
            r = sqlite3_step(sql)
        }
        
        if r == SQLITE_DONE { r = sqlite3_finalize(sql) }
        if r != SQLITE_OK { print(String(cString: sqlite3_errmsg(db))) }
        return blocks
    }
    
    private func saveBlocks(blocks: [UnsafeMutablePointer<BRMerkleBlock>?]) {
        var sql: OpaquePointer? = nil
        var pk: Int32 = 0
        var r: Int32
        
        r = sqlite3_exec(db, "begin exclusive", nil, nil, nil)
        if r == SQLITE_OK && blocks.count > 1 {
            r = sqlite3_exec(db, "delete from ZBRMERKLEBLOCKENTITY", nil, nil, nil)
        }
        else if r == SQLITE_OK {
            r = sqlite3_prepare_v2(db, "select Z_MAX from Z_PRIMARYKEY where Z_ENT = \(blockEnt)", -1, &sql, nil)
            if r == SQLITE_OK { r = sqlite3_step(sql) }
            if r == SQLITE_ROW {
                pk = sqlite3_column_int(sql, 0)
                r = sqlite3_finalize(sql)
            }
        }
        if r == SQLITE_OK {
            r = sqlite3_prepare_v2(db, "insert into ZBRMERKLEBLOCKENTITY (Z_PK, Z_ENT, Z_OPT, ZHEIGHT, ZNONCE, " +
                "ZTARGET, ZTOTALTRANSACTIONS, ZVERSION, ZTIMESTAMP, ZBLOCKHASH, ZFLAGS, ZHASHES, ZMERKLEROOT, " +
                "ZPREVBLOCK) values (?, \(blockEnt), 1, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", -1, &sql, nil)
        }
        
        for b in blocks {
            pk = pk + 1
            if r == SQLITE_OK { r = sqlite3_bind_int(sql, 1, pk) }
            if r == SQLITE_OK { r = sqlite3_bind_int(sql, 2, Int32(bitPattern: b!.pointee.height)) }
            if r == SQLITE_OK { r = sqlite3_bind_int(sql, 3, Int32(bitPattern: b!.pointee.nonce)) }
            if r == SQLITE_OK { r = sqlite3_bind_int(sql, 4, Int32(bitPattern: b!.pointee.target)) }
            if r == SQLITE_OK { r = sqlite3_bind_int(sql, 5, Int32(bitPattern: b!.pointee.totalTx)) }
            if r == SQLITE_OK { r = sqlite3_bind_int(sql, 6, Int32(bitPattern: b!.pointee.version)) }
            if r == SQLITE_OK { r = sqlite3_bind_int(sql, 7, Int32(bitPattern: b!.pointee.timestamp)) }
            if r == SQLITE_OK {
                r = sqlite3_bind_blob(sql, 8, [b!.pointee.blockHash], Int32(MemoryLayout<UInt256>.size),
                                      SQLITE_TRANSIENT)
            }
            if r == SQLITE_OK {
                r = sqlite3_bind_blob(sql, 9, [b!.pointee.flags], Int32(b!.pointee.flagsLen), SQLITE_TRANSIENT)
            }
            if r == SQLITE_OK {
                r = sqlite3_bind_blob(sql, 10, [b!.pointee.hashes],
                                      Int32(MemoryLayout<UInt256>.size*b!.pointee.hashesCount), SQLITE_TRANSIENT)
            }
            if r == SQLITE_OK {
                r = sqlite3_bind_blob(sql, 11, [b!.pointee.merkleRoot], Int32(MemoryLayout<UInt256>.size),
                                      SQLITE_TRANSIENT)
            }
            if r == SQLITE_OK {
                r = sqlite3_bind_blob(sql, 12, [b!.pointee.prevBlock], Int32(MemoryLayout<UInt256>.size),
                                      SQLITE_TRANSIENT)
            }
            if r == SQLITE_OK { r = sqlite3_step(sql) }
            if r == SQLITE_DONE { r = sqlite3_reset(sql) }
        }
        
        if r == SQLITE_OK {
            r = sqlite3_exec(db, "update or fail Z_PRIMARYKEY set Z_MAX = \(pk) where Z_ENT = \(blockEnt)",
                nil, nil, nil)
        }
        if r == SQLITE_OK { r = sqlite3_exec(db, "commit", nil, nil, nil) }
        if r == SQLITE_OK { r = sqlite3_finalize(sql) }
        if r != SQLITE_OK { print(String(cString: sqlite3_errmsg(db))) }
    }
    
    private func loadPeers() -> [BRPeer] {
        var sql: OpaquePointer? = nil
        var peers = [BRPeer]()
        var r: Int32

        r = sqlite3_prepare_v2(db, "select ZADDRESS, ZPORT, ZSERVICES, ZTIMESTAMP from ZBRPEERENTITY", -1, &sql, nil)
        if r == SQLITE_OK { r = sqlite3_step(sql) }
        
        while r == SQLITE_ROW {
            var peer = BRPeer()
            
            peer.address = UInt128(u32: (0, 0, UInt32(0xffff).bigEndian,
                                         UInt32(bitPattern: sqlite3_column_int(sql, 0)).bigEndian))
            peer.port = UInt16(truncatingBitPattern: sqlite3_column_int(sql, 1))
            peer.services = UInt64(bitPattern: sqlite3_column_int64(sql, 2))
            peer.timestamp = UInt64(bitPattern: sqlite3_column_int64(sql, 3))
            peers.append(peer)
            r = sqlite3_step(sql)
        }
        
        if r == SQLITE_DONE { r = sqlite3_finalize(sql) }
        if r != SQLITE_OK { print(String(cString: sqlite3_errmsg(db))) }
        return peers
    }
    
    private func savePeers(peers: [BRPeer]) {
        var sql: OpaquePointer? = nil
        var pk: Int32 = 0
        var r: Int32
        
        r = sqlite3_exec(db, "begin exclusive", nil, nil, nil)
        if r == SQLITE_OK && peers.count > 1 {
            r = sqlite3_exec(db, "delete from ZBRPEERENTITY", nil, nil, nil)
        }
        else if r == SQLITE_OK {
            r = sqlite3_prepare_v2(db, "select Z_MAX from Z_PRIMARYKEY where Z_ENT = \(peerEnt)", -1, &sql, nil)
            if r == SQLITE_OK { r = sqlite3_step(sql) }
            if r == SQLITE_ROW {
                pk = sqlite3_column_int(sql, 0)
                r = sqlite3_finalize(sql)
            }
        }
        if r == SQLITE_OK {
            r = sqlite3_prepare_v2(db, "insert into ZBRPEERENTITY (Z_PK, Z_ENT, Z_OPT, ZADDRESS, ZMISBEHAVIN, ZPORT," +
                "ZSERVICES, ZTIMESTAMP) values (?, \(peerEnt), 1, ?, 0, ?, ?, ?)", -1, &sql, nil)
        }
        
        for p in peers {
            pk = pk + 1
            if r == SQLITE_OK { r = sqlite3_bind_int(sql, 1, pk) }
            if r == SQLITE_OK { r = sqlite3_bind_int(sql, 2, peerEnt) }
            if r == SQLITE_OK { r = sqlite3_bind_int(sql, 3, Int32(bitPattern: p.address.u32.3)) }
            if r == SQLITE_OK { r = sqlite3_bind_int(sql, 4, Int32(p.port)) }
            if r == SQLITE_OK { r = sqlite3_bind_int64(sql, 5, Int64(bitPattern: p.services)) }
            if r == SQLITE_OK { r = sqlite3_bind_int64(sql, 6, Int64(bitPattern: p.timestamp)) }
            if r == SQLITE_OK { r = sqlite3_step(sql) }
            if r == SQLITE_DONE { r = sqlite3_reset(sql) }
        }
        
        if r == SQLITE_OK {
            r = sqlite3_exec(db, "update or fail Z_PRIMARYKEY set Z_MAX = \(pk) where Z_ENT = \(peerEnt)",
                nil, nil, nil)
        }
        if r == SQLITE_OK { r = sqlite3_exec(db, "commit", nil, nil, nil) }
        if r == SQLITE_OK { r = sqlite3_finalize(sql) }
        if r != SQLITE_OK { print(String(cString: sqlite3_errmsg(db))) }
    }
    
    private func isNetworkReachable() -> Bool {
        var zeroAddress = sockaddr()
        
        zeroAddress.sa_len = UInt8(MemoryLayout<sockaddr>.size)
        zeroAddress.sa_family = sa_family_t(AF_INET)
        
        let reachability = SCNetworkReachabilityCreateWithAddress(nil, &zeroAddress)
        var flags: SCNetworkReachabilityFlags = []
        
        if !SCNetworkReachabilityGetFlags(reachability!, &flags) {
            return false
        }
        
        return flags.contains(.reachable) && !flags.contains(.connectionRequired)
    }
    
    deinit {
        BRPeerManagerDisconnect(peerManager)
        BRPeerManagerFree(peerManager)
        BRWalletFree(wallet)
        
        if sqlite3_close(db) != SQLITE_OK {
            print("error closing database")
        }
    }
}
