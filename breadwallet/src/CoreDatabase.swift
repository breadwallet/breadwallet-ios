//
//  Database.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-11-10.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation
import BRCore
import sqlite3

// swiftlint:disable type_body_length

internal let SQLITE_STATIC = unsafeBitCast(0, to: sqlite3_destructor_type.self)
internal let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

enum WalletManagerError: Error {
    case sqliteError(errorCode: Int32, description: String)
}

private func SafeSqlite3ColumnBlob<T>(statement: OpaquePointer, iCol: Int32) -> UnsafePointer<T>? {
    guard let result = sqlite3_column_blob(statement, iCol) else { return nil }
    return result.assumingMemoryBound(to: T.self)
}

class CoreDatabase {

    private let dbPath: String
    private var db: OpaquePointer?
    private var txEnt: Int32 = 0
    private var blockEnt: Int32 = 0
    private var peerEnt: Int32 = 0
    private let queue = DispatchQueue(label: "com.breadwallet.corecbqueue")

    private var currency: Currency {
        return [Currencies.btc, Currencies.bch].first { $0.dbPath == dbPath } ?? Currencies.btc
    }

    init(dbPath: String = "BreadWallet.sqlite") {
        let docsUrl = try? FileManager.default.url(for: .documentDirectory,
                                                   in: .userDomainMask,
                                                   appropriateFor: nil,
                                                   create: false)
        self.dbPath = docsUrl?.appendingPathComponent(dbPath).path ?? ""

        queue.async {
            try? self.openDatabase()
        }
    }

    deinit {
        if db != nil { sqlite3_close(db) }
    }

    func close() {
        if db != nil { sqlite3_close(db) }
    }

    func delete() {
        try? FileManager.default.removeItem(atPath: dbPath)
    }

    private func openDatabase() throws {
        // open sqlite database
        if sqlite3_open_v2( self.dbPath, &db,
                            SQLITE_OPEN_FULLMUTEX | SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE, nil
            ) != SQLITE_OK {
            print(String(cString: sqlite3_errmsg(db)))

            #if DEBUG
                throw WalletManagerError.sqliteError(errorCode: sqlite3_errcode(db),
                                                     description: String(cString: sqlite3_errmsg(db)))
            #else
                try FileManager.default.removeItem(atPath: self.dbPath)

                if sqlite3_open_v2( self.dbPath, &db,
                                    SQLITE_OPEN_FULLMUTEX | SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE, nil
                    ) != SQLITE_OK {
                    throw WalletManagerError.sqliteError(errorCode: sqlite3_errcode(db),
                                                         description: String(cString: sqlite3_errmsg(db)))
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
        if sqlite3_errcode(db) != SQLITE_OK { print(String(cString: sqlite3_errmsg(db))) }

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
        if sqlite3_errcode(db) != SQLITE_OK { print(String(cString: sqlite3_errmsg(db))) }

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
        if sqlite3_errcode(db) != SQLITE_OK { print(String(cString: sqlite3_errmsg(db))) }

        // primary keys
        sqlite3_exec(db, "create table if not exists Z_PRIMARYKEY (" +
            "Z_ENT INTEGER PRIMARY KEY," +
            "Z_NAME VARCHAR," +
            "Z_SUPER INTEGER," +
            "Z_MAX INTEGER)", nil, nil, nil)
        sqlite3_exec(db, "insert into Z_PRIMARYKEY (Z_ENT, Z_NAME, Z_SUPER, Z_MAX) " +
            "select 6, 'BRTxMetadataEntity', 0, 0 except " +
            "select 6, Z_NAME, 0, 0 from Z_PRIMARYKEY where Z_NAME = 'BRTxMetadataEntity'", nil, nil, nil)
        sqlite3_exec(db, "insert into Z_PRIMARYKEY (Z_ENT, Z_NAME, Z_SUPER, Z_MAX) " +
            "select 2, 'BRMerkleBlockEntity', 0, 0 except " +
            "select 2, Z_NAME, 0, 0 from Z_PRIMARYKEY where Z_NAME = 'BRMerkleBlockEntity'", nil, nil, nil)
        sqlite3_exec(db, "insert into Z_PRIMARYKEY (Z_ENT, Z_NAME, Z_SUPER, Z_MAX) " +
            "select 3, 'BRPeerEntity', 0, 0 except " +
            "select 3, Z_NAME, 0, 0 from Z_PRIMARYKEY where Z_NAME = 'BRPeerEntity'", nil, nil, nil)
        if sqlite3_errcode(db) != SQLITE_OK { print(String(cString: sqlite3_errmsg(db))) }

        var sql: OpaquePointer?
        sqlite3_prepare_v2(db, "select Z_ENT, Z_NAME from Z_PRIMARYKEY", -1, &sql, nil)
        defer { sqlite3_finalize(sql) }

        while sqlite3_step(sql) == SQLITE_ROW {
            let name = String(cString: sqlite3_column_text(sql, 1))
            if name == "BRTxMetadataEntity" {
                txEnt = sqlite3_column_int(sql, 0)
            } else if name == "BRMerkleBlockEntity" {
                blockEnt = sqlite3_column_int(sql, 0)
            } else if name == "BRPeerEntity" {
                peerEnt = sqlite3_column_int(sql, 0)
            }
        }

        if sqlite3_errcode(db) != SQLITE_DONE { print(String(cString: sqlite3_errmsg(db))) }
    }

    func txAdded(_ tx: BRTxRef) {
        queue.async {
            var buf = [UInt8](repeating: 0, count: BRTransactionSerialize(tx, nil, 0))
            let timestamp = (tx.pointee.timestamp > UInt32(NSTimeIntervalSince1970)) ? tx.pointee.timestamp - UInt32(NSTimeIntervalSince1970) : 0
            guard BRTransactionSerialize(tx, &buf, buf.count) == buf.count else { return }
            [tx.pointee.blockHeight.littleEndian, timestamp.littleEndian].withUnsafeBytes { buf.append(contentsOf: $0) }
            sqlite3_exec(self.db, "begin exclusive", nil, nil, nil)

            var sql: OpaquePointer?
            sqlite3_prepare_v2(self.db, "select Z_MAX from Z_PRIMARYKEY where Z_ENT = \(self.txEnt)", -1, &sql, nil)
            defer { sqlite3_finalize(sql) }

            guard sqlite3_step(sql) == SQLITE_ROW else {
                print(String(cString: sqlite3_errmsg(self.db)))
                sqlite3_exec(self.db, "rollback", nil, nil, nil)
                return
            }

            let pk = sqlite3_column_int(sql, 0)
            var sql2: OpaquePointer?
            sqlite3_prepare_v2(self.db, "insert or rollback into ZBRTXMETADATAENTITY " +
                "(Z_PK, Z_ENT, Z_OPT, ZTYPE, ZBLOB, ZTXHASH) " +
                "values (\(pk + 1), \(self.txEnt), 1, 1, ?, ?)", -1, &sql2, nil)
            defer { sqlite3_finalize(sql2) }
            sqlite3_bind_blob(sql2, 1, buf, Int32(buf.count), SQLITE_TRANSIENT)
            sqlite3_bind_blob(sql2, 2, [tx.pointee.txHash], Int32(MemoryLayout<UInt256>.size), SQLITE_TRANSIENT)

            guard sqlite3_step(sql2) == SQLITE_DONE else {
                print(String(cString: sqlite3_errmsg(self.db)))
                return
            }

            sqlite3_exec(self.db, "update or rollback Z_PRIMARYKEY set Z_MAX = \(pk + 1) " +
                "where Z_ENT = \(self.txEnt) and Z_MAX = \(pk)", nil, nil, nil)

            guard sqlite3_errcode(self.db) == SQLITE_OK else {
                print(String(cString: sqlite3_errmsg(self.db)))
                return
            }

            sqlite3_exec(self.db, "commit", nil, nil, nil)
            self.setDBFileAttributes()
        }
    }

    func setDBFileAttributes() {
        queue.async {
            let files = [self.dbPath, self.dbPath + "-shm", self.dbPath + "-wal"]
            files.forEach {
                if FileManager.default.fileExists(atPath: $0) {
                    do {
                        try FileManager.default.setAttributes([FileAttributeKey.protectionKey: FileProtectionType.none], ofItemAtPath: $0)
                    } catch let e {
                        print("Set db attributes error: \(e)")
                    }
                }
            }
        }
    }

    func txUpdated(_ txHashes: [UInt256], blockHeight: UInt32, timestamp: UInt32) {
        queue.async {
            guard !txHashes.isEmpty else { return }
            let timestamp = (timestamp > UInt32(NSTimeIntervalSince1970)) ? timestamp - UInt32(NSTimeIntervalSince1970) : 0
            var sql: OpaquePointer? = nil, sql2: OpaquePointer? = nil, count = 0
            sqlite3_prepare_v2(self.db, "select ZTXHASH, ZBLOB from ZBRTXMETADATAENTITY where ZTYPE = 1 and " +
                "ZTXHASH in (" + String(repeating: "?, ", count: txHashes.count - 1) + "?)", -1, &sql, nil)
            defer { sqlite3_finalize(sql) }

            for i in 0..<txHashes.count {
                sqlite3_bind_blob(sql, Int32(i + 1), [txHashes[i]], Int32(MemoryLayout<UInt256>.size), SQLITE_TRANSIENT)
            }

            sqlite3_prepare_v2(self.db, "update ZBRTXMETADATAENTITY set ZBLOB = ? where ZTXHASH = ?", -1, &sql2, nil)
            defer { sqlite3_finalize(sql2) }

            while sqlite3_step(sql) == SQLITE_ROW {
                let hash = sqlite3_column_blob(sql, 0)
                let buf = sqlite3_column_blob(sql, 1).assumingMemoryBound(to: UInt8.self)
                var blob = [UInt8](UnsafeBufferPointer(start: buf, count: Int(sqlite3_column_bytes(sql, 1))))

                [blockHeight.littleEndian, timestamp.littleEndian].withUnsafeBytes {
                    if blob.count > $0.count {
                        blob.replaceSubrange(blob.count - $0.count..<blob.count, with: $0)
                        sqlite3_bind_blob(sql2, 1, blob, Int32(blob.count), SQLITE_TRANSIENT)
                        sqlite3_bind_blob(sql2, 2, hash, Int32(MemoryLayout<UInt256>.size), SQLITE_TRANSIENT)
                        sqlite3_step(sql2)
                        sqlite3_reset(sql2)
                    }
                }
                
                count += 1
            }

            if sqlite3_errcode(self.db) != SQLITE_DONE { print(String(cString: sqlite3_errmsg(self.db))) }

            if count != txHashes.count {
                print("Fewer tx records updated than hashes! This causes tx to go missing!")
                exit(0) // DIE! DIE! DIE!
            }
        }
    }

    func txDeleted(_ txHash: UInt256, notifyUser: Bool, recommendRescan: Bool) {
        queue.async {
            var sql: OpaquePointer?
            sqlite3_prepare_v2(self.db, "delete from ZBRTXMETADATAENTITY where ZTYPE = 1 and ZTXHASH = ?", -1, &sql, nil)
            defer { sqlite3_finalize(sql) }
            sqlite3_bind_blob(sql, 1, [txHash], Int32(MemoryLayout<UInt256>.size), SQLITE_TRANSIENT)

            guard sqlite3_step(sql) == SQLITE_DONE else {
                print(String(cString: sqlite3_errmsg(self.db)))
                return
            }
        }
    }

    func saveBlocks(_ replace: Bool, _ blockRefs: [BRBlockRef?]) {
        // make a copy before crossing thread boundary
        let blocks: [BRBlockRef?] = blockRefs.map { blockRef in
            if let b = blockRef {
                return BRMerkleBlockCopy(&b.pointee)
            } else {
                return nil
            }
        }
        
        queue.async {
            var pk: Int32 = 0
            sqlite3_exec(self.db, "begin exclusive", nil, nil, nil)

            if replace { // delete existing blocks and replace
                sqlite3_exec(self.db, "delete from ZBRMERKLEBLOCKENTITY", nil, nil, nil)
            } else { // add to existing blocks
                var sql: OpaquePointer?
                sqlite3_prepare_v2(self.db, "select Z_MAX from Z_PRIMARYKEY where Z_ENT = \(self.blockEnt)", -1, &sql, nil)
                defer { sqlite3_finalize(sql) }

                guard sqlite3_step(sql) == SQLITE_ROW else {
                    print(String(cString: sqlite3_errmsg(self.db)))
                    sqlite3_exec(self.db, "rollback", nil, nil, nil)
                    return
                }

                pk = sqlite3_column_int(sql, 0) // get last primary key
            }

            var sql2: OpaquePointer?
            sqlite3_prepare_v2(self.db, "insert or rollback into ZBRMERKLEBLOCKENTITY (Z_PK, Z_ENT, Z_OPT, ZHEIGHT, " +
                "ZNONCE, ZTARGET, ZTOTALTRANSACTIONS, ZVERSION, ZTIMESTAMP, ZBLOCKHASH, ZFLAGS, ZHASHES, " +
                "ZMERKLEROOT, ZPREVBLOCK) values (?, \(self.blockEnt), 1, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", -1, &sql2, nil)
            defer { sqlite3_finalize(sql2) }

            for b in blocks {
                guard let b = b else {
                    sqlite3_exec(self.db, "rollback", nil, nil, nil)
                    return
                }

                let timestampResult = Int32(bitPattern: b.pointee.timestamp).subtractingReportingOverflow(Int32(NSTimeIntervalSince1970))
                guard !timestampResult.1 else { print("skipped block with overflowed timestamp"); continue }
                
                let height = Int32(bitPattern: b.pointee.height)
                guard height != BLOCK_UNKNOWN_HEIGHT else {
                    print("skipped block with invalid blockheight: \(height)")
                    continue
                }

                pk += 1
                sqlite3_bind_int(sql2, 1, pk)
                sqlite3_bind_int(sql2, 2, Int32(bitPattern: b.pointee.height))
                sqlite3_bind_int(sql2, 3, Int32(bitPattern: b.pointee.nonce))
                sqlite3_bind_int(sql2, 4, Int32(bitPattern: b.pointee.target))
                sqlite3_bind_int(sql2, 5, Int32(bitPattern: b.pointee.totalTx))
                sqlite3_bind_int(sql2, 6, Int32(bitPattern: b.pointee.version))
                sqlite3_bind_int(sql2, 7, timestampResult.0)
                sqlite3_bind_blob(sql2, 8, &b.pointee.blockHash, Int32(MemoryLayout<UInt256>.size), SQLITE_TRANSIENT)
                sqlite3_bind_blob(sql2, 9, b.pointee.flags, Int32(b.pointee.flagsLen), SQLITE_TRANSIENT)
                sqlite3_bind_blob(sql2, 10, b.pointee.hashes, Int32(MemoryLayout<UInt256>.size*b.pointee.hashesCount),
                                  SQLITE_TRANSIENT)
                sqlite3_bind_blob(sql2, 11, &b.pointee.merkleRoot, Int32(MemoryLayout<UInt256>.size), SQLITE_TRANSIENT)
                sqlite3_bind_blob(sql2, 12, &b.pointee.prevBlock, Int32(MemoryLayout<UInt256>.size), SQLITE_TRANSIENT)

                guard sqlite3_step(sql2) == SQLITE_DONE else {
                    print(String(cString: sqlite3_errmsg(self.db)))
                    return
                }

                sqlite3_reset(sql2)
                
                BRMerkleBlockFree(b)
            }

            sqlite3_exec(self.db, "update or rollback Z_PRIMARYKEY set Z_MAX = \(pk) where Z_ENT = \(self.blockEnt)",
                nil, nil, nil)

            guard sqlite3_errcode(self.db) == SQLITE_OK else {
                print(String(cString: sqlite3_errmsg(self.db)))
                return
            }

            sqlite3_exec(self.db, "commit", nil, nil, nil)
        }
    }

    func savePeers(_ replace: Bool, _ peers: [BRPeer]) {
        queue.async {
            var pk: Int32 = 0
            sqlite3_exec(self.db, "begin exclusive", nil, nil, nil)

            if replace { // delete existing peers and replace
                sqlite3_exec(self.db, "delete from ZBRPEERENTITY", nil, nil, nil)
            } else { // add to existing peers
                var sql: OpaquePointer?
                sqlite3_prepare_v2(self.db, "select Z_MAX from Z_PRIMARYKEY where Z_ENT = \(self.peerEnt)", -1, &sql, nil)
                defer { sqlite3_finalize(sql) }

                guard sqlite3_step(sql) == SQLITE_ROW else {
                    print(String(cString: sqlite3_errmsg(self.db)))
                    sqlite3_exec(self.db, "rollback", nil, nil, nil)
                    return
                }

                pk = sqlite3_column_int(sql, 0) // get last primary key
            }

            var sql2: OpaquePointer?
            sqlite3_prepare_v2(self.db, "insert or rollback into ZBRPEERENTITY " +
                "(Z_PK, Z_ENT, Z_OPT, ZADDRESS, ZMISBEHAVIN, ZPORT, ZSERVICES, ZTIMESTAMP) " +
                "values (?, \(self.peerEnt), 1, ?, 0, ?, ?, ?)", -1, &sql2, nil)
            defer { sqlite3_finalize(sql2) }

            for p in peers {
                pk += 1
                sqlite3_bind_int(sql2, 1, pk)
                sqlite3_bind_int(sql2, 2, Int32(bitPattern: p.address.u32.3.bigEndian))
                sqlite3_bind_int(sql2, 3, Int32(p.port))
                sqlite3_bind_int64(sql2, 4, Int64(bitPattern: p.services))
                sqlite3_bind_int64(sql2, 5, Int64(bitPattern: p.timestamp) - Int64(NSTimeIntervalSince1970))

                guard sqlite3_step(sql2) == SQLITE_DONE else {
                    print(String(cString: sqlite3_errmsg(self.db)))
                    return
                }

                sqlite3_reset(sql2)
            }

            sqlite3_exec(self.db, "update or rollback Z_PRIMARYKEY set Z_MAX = \(pk) where Z_ENT = \(self.peerEnt)",
                nil, nil, nil)

            guard sqlite3_errcode(self.db) == SQLITE_OK else {
                print(String(cString: sqlite3_errmsg(self.db)))
                return
            }

            sqlite3_exec(self.db, "commit", nil, nil, nil)
        }
    }

    func loadTransactions(callback: @escaping ([BRTxRef?]) -> Void) {
        queue.async {
            var transactions = [BRTxRef?]()
            var sql: OpaquePointer?
            sqlite3_prepare_v2(self.db, "select ZBLOB from ZBRTXMETADATAENTITY where ZTYPE = 1", -1, &sql, nil)
            defer { sqlite3_finalize(sql) }

            while sqlite3_step(sql) == SQLITE_ROW {
                let len = Int(sqlite3_column_bytes(sql, 0))
                let buf = sqlite3_column_blob(sql, 0).assumingMemoryBound(to: UInt8.self)
                guard len >= MemoryLayout<UInt32>.size*2 else { return DispatchQueue.main.async { callback(transactions) }}
                var off = len - MemoryLayout<UInt32>.size*2

                guard let tx = BRTransactionParse(buf, off) else {
                    // unable to parse tx in db -- rescan from last sent (or earlier)
                    print("failed to parse transaction from db")
                    Store.trigger(name: .automaticRescan(self.currency))
                    continue
                }
                tx.pointee.blockHeight =
                    UnsafeRawPointer(buf).advanced(by: off).assumingMemoryBound(to: UInt32.self).pointee.littleEndian
                off += MemoryLayout<UInt32>.size
                let timestamp = UnsafeRawPointer(buf).advanced(by: off).assumingMemoryBound(to: UInt32.self).pointee.littleEndian
                tx.pointee.timestamp = (timestamp == 0) ? timestamp : timestamp + UInt32(NSTimeIntervalSince1970)
                transactions.append(tx)
            }

            if sqlite3_errcode(self.db) != SQLITE_DONE { print(String(cString: sqlite3_errmsg(self.db))) }
            DispatchQueue.main.async {
                callback(transactions)
            }
        }
    }

    func loadBlocks(callback: @escaping ([BRBlockRef?]) -> Void) {
        queue.async {
            var blocks = [BRBlockRef?]()
            var sql: OpaquePointer?
            sqlite3_prepare_v2(self.db, "select ZHEIGHT, ZNONCE, ZTARGET, ZTOTALTRANSACTIONS, ZVERSION, ZTIMESTAMP, " +
                "ZBLOCKHASH, ZFLAGS, ZHASHES, ZMERKLEROOT, ZPREVBLOCK from ZBRMERKLEBLOCKENTITY", -1, &sql, nil)
            defer { sqlite3_finalize(sql) }

            while sqlite3_step(sql) == SQLITE_ROW {
                guard let b = BRMerkleBlockNew() else { return DispatchQueue.main.async { callback(blocks) }}
                b.pointee.height = UInt32(bitPattern: sqlite3_column_int(sql, 0))
                guard b.pointee.height != BLOCK_UNKNOWN_HEIGHT else {
                    print("skipped invalid blockheight: \(sqlite3_column_int(sql, 0))")
                    continue
                }
                b.pointee.nonce = UInt32(bitPattern: sqlite3_column_int(sql, 1))
                b.pointee.target = UInt32(bitPattern: sqlite3_column_int(sql, 2))
                b.pointee.totalTx = UInt32(bitPattern: sqlite3_column_int(sql, 3))
                b.pointee.version = UInt32(bitPattern: sqlite3_column_int(sql, 4))
                let result = UInt32(bitPattern: sqlite3_column_int(sql, 5)).addingReportingOverflow(UInt32(NSTimeIntervalSince1970))
                if result.1 {
                    print("skipped overflowed timestamp: \(sqlite3_column_int(sql, 5))")
                    continue
                } else {
                    b.pointee.timestamp = result.0
                }
                b.pointee.blockHash = sqlite3_column_blob(sql, 6).assumingMemoryBound(to: UInt256.self).pointee

                let flags: UnsafePointer<UInt8>? = SafeSqlite3ColumnBlob(statement: sql!, iCol: 7)
                let flagsLen = Int(sqlite3_column_bytes(sql, 7))
                let hashes: UnsafePointer<UInt256>? = SafeSqlite3ColumnBlob(statement: sql!, iCol: 8)
                let hashesCount = Int(sqlite3_column_bytes(sql, 8))/MemoryLayout<UInt256>.size
                BRMerkleBlockSetTxHashes(b, hashes, hashesCount, flags, flagsLen)
                b.pointee.merkleRoot = sqlite3_column_blob(sql, 9).assumingMemoryBound(to: UInt256.self).pointee
                b.pointee.prevBlock = sqlite3_column_blob(sql, 10).assumingMemoryBound(to: UInt256.self).pointee
                blocks.append(b)
            }

            if sqlite3_errcode(self.db) != SQLITE_DONE { print(String(cString: sqlite3_errmsg(self.db))) }
            DispatchQueue.main.async {
                callback(blocks)
            }
        }
    }

    func loadPeers(callback: @escaping ([BRPeer]) -> Void) {
        queue.async {
            var peers = [BRPeer]()
            var sql: OpaquePointer?
            sqlite3_prepare_v2(self.db, "select ZADDRESS, ZPORT, ZSERVICES, ZTIMESTAMP from ZBRPEERENTITY", -1, &sql, nil)
            defer { sqlite3_finalize(sql) }

            while sqlite3_step(sql) == SQLITE_ROW {
                var p = BRPeer()
                p.address = UInt128(u32: (0, 0, UInt32(0xffff).bigEndian,
                                          UInt32(bitPattern: sqlite3_column_int(sql, 0)).bigEndian))
                p.port = UInt16(truncatingIfNeeded: sqlite3_column_int(sql, 1))
                p.services = UInt64(bitPattern: sqlite3_column_int64(sql, 2))

                let result = UInt64(bitPattern: sqlite3_column_int64(sql, 3)).addingReportingOverflow(UInt64(NSTimeIntervalSince1970))
                if result.1 {
                    print("skipped overflowed timestamp: \(sqlite3_column_int64(sql, 3))")
                    continue
                } else {
                    p.timestamp = result.0
                    peers.append(p)
                }
            }

            if sqlite3_errcode(self.db) != SQLITE_DONE { print(String(cString: sqlite3_errmsg(self.db))) }
            DispatchQueue.main.async {
                callback(peers)
            }
        }
    }
}
