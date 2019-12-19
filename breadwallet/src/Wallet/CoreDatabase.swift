//
//  CoreDatabase.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-11-10.
//  Copyright © 2017-2019 Breadwinner AG. All rights reserved.
//

import Foundation
import SQLite3
import BRCrypto

enum CoreDatabaseError: Error {
    case sqliteError(errorCode: Int32, description: String)
}

class CoreDatabase {

    private var db: OpaquePointer?

    deinit {
        if db != nil { sqlite3_close(db) }
    }

    func close() {
        if db != nil {
            sqlite3_close(db)
            db = nil
        }
    }
    
    func openDatabase(path: String) throws {
        // open sqlite database
        if sqlite3_open_v2( path, &db,
                            SQLITE_OPEN_FULLMUTEX | SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE, nil
            ) != SQLITE_OK {
            print(String(cString: sqlite3_errmsg(db)))
            throw CoreDatabaseError.sqliteError(errorCode: sqlite3_errcode(db),
                                                description: String(cString: sqlite3_errmsg(db)))
        }
    }

    func loadTransactions() -> [System.TransactionBlob] {
        var transactions = [System.TransactionBlob]()
        
        var sql: OpaquePointer?
        sqlite3_prepare_v2(self.db, "select ZBLOB from ZBRTXMETADATAENTITY where ZTYPE = 1", -1, &sql, nil)
        defer { sqlite3_finalize(sql) }
        
        while sqlite3_step(sql) == SQLITE_ROW {
            let len = Int(sqlite3_column_bytes(sql, 0))
            let buf = sqlite3_column_blob(sql, 0).assumingMemoryBound(to: UInt8.self)
            guard len >= MemoryLayout<UInt32>.size*2 else { return transactions }
            var off = len - MemoryLayout<UInt32>.size*2
            
            let bytes = [UInt8](Data(bytes: buf, count: off))
            let blockHeight =
                UnsafeRawPointer(buf).advanced(by: off).assumingMemoryBound(to: UInt32.self).pointee.littleEndian
            off += MemoryLayout<UInt32>.size
            var timestamp = UnsafeRawPointer(buf).advanced(by: off).assumingMemoryBound(to: UInt32.self).pointee.littleEndian
            timestamp = (timestamp == 0) ? timestamp : timestamp + UInt32(NSTimeIntervalSince1970)
            transactions.append(System.TransactionBlob.btc(bytes: bytes, blockHeight: blockHeight, timestamp: timestamp))
        }
        
        if sqlite3_errcode(self.db) != SQLITE_DONE { print(String(cString: sqlite3_errmsg(self.db))) }
        return transactions
    }
    
    func loadBlocks() -> [System.BlockBlob] {
        var blocks = [System.BlockBlob]()
        
        let hashBytes = 32 // stored as UInt256
        
        var sql: OpaquePointer?
        sqlite3_prepare_v2(self.db, "select ZHEIGHT, ZNONCE, ZTARGET, ZTOTALTRANSACTIONS, ZVERSION, ZTIMESTAMP, " +
            "ZBLOCKHASH, ZFLAGS, ZHASHES, ZMERKLEROOT, ZPREVBLOCK from ZBRMERKLEBLOCKENTITY", -1, &sql, nil)
        defer { sqlite3_finalize(sql) }
        
        while sqlite3_step(sql) == SQLITE_ROW {
            
            let height = UInt32(bitPattern: sqlite3_column_int(sql, 0))
            let nonce = UInt32(bitPattern: sqlite3_column_int(sql, 1))
            let target = UInt32(bitPattern: sqlite3_column_int(sql, 2))
            let txCount = UInt32(bitPattern: sqlite3_column_int(sql, 3))
            let version = UInt32(bitPattern: sqlite3_column_int(sql, 4))
            let (timestamp, timestampOverflow) = UInt32(bitPattern: sqlite3_column_int(sql, 5)).addingReportingOverflow(UInt32(NSTimeIntervalSince1970))
            let blockHashBlob = sqlite3_column_blob(sql, 6).assumingMemoryBound(to: UInt8.self)
            let blockHash = [UInt8](Data(bytes: blockHashBlob, count: hashBytes))
            
            let flagsBlob = sqlite3_column_blob(sql, 7)?.assumingMemoryBound(to: UInt8.self)
            let flagsLen = Int(sqlite3_column_bytes(sql, 7))
            let flags = (flagsLen > 0 && flagsBlob != nil) ? [UInt8](Data(bytes: flagsBlob!, count: flagsLen)) : [UInt8]()
            
            let hashesBlob = sqlite3_column_blob(sql, 8)?.assumingMemoryBound(to: UInt8.self)
            let hashesCount = Int(sqlite3_column_bytes(sql, 8))/hashBytes
            var hashes: [System.BlockHash] = []
            if hashesBlob != nil {
                for i in 0..<hashesCount {
                    hashes.append([UInt8](Data(bytes: hashesBlob!.advanced(by: i*hashBytes), count: hashBytes)))
                }
            }
            
            let merkleRootBlob = sqlite3_column_blob(sql, 9).assumingMemoryBound(to: UInt8.self)
            let merkleRoot = [UInt8](Data(bytes: merkleRootBlob, count: hashBytes)) // stored as UInt256
            
            let prevBlockBlob = sqlite3_column_blob(sql, 10).assumingMemoryBound(to: UInt8.self)
            let prevBlock = [UInt8](Data(bytes: prevBlockBlob, count: hashBytes)) // stored as UInt256
            
            blocks.append(System.BlockBlob.btc(hash: blockHash,
                                               height: height,
                                               nonce: nonce,
                                               target: target,
                                               txCount: txCount,
                                               version: version,
                                               timestamp: timestampOverflow ? nil : timestamp,
                                               flags: flags,
                                               hashes: hashes,
                                               merkleRoot: merkleRoot,
                                               prevBlock: prevBlock))
        }
        
        if sqlite3_errcode(self.db) != SQLITE_DONE { print(String(cString: sqlite3_errmsg(self.db))) }
        return blocks
    }
    
    func loadPeers() -> [System.PeerBlob] {
        var peers = [System.PeerBlob]()
        var sql: OpaquePointer?
        sqlite3_prepare_v2(self.db, "select ZADDRESS, ZPORT, ZSERVICES, ZTIMESTAMP from ZBRPEERENTITY", -1, &sql, nil)
        defer { sqlite3_finalize(sql) }
        
        while sqlite3_step(sql) == SQLITE_ROW {
            let address = UInt32(bitPattern: sqlite3_column_int(sql, 0)).bigEndian//UInt128(u32: (0, 0, UInt32(0xffff).bigEndian,
                            //          UInt32(bitPattern: sqlite3_column_int(sql, 0)).bigEndian))
            let port = UInt16(truncatingIfNeeded: sqlite3_column_int(sql, 1))
            let services = UInt64(bitPattern: sqlite3_column_int64(sql, 2))
            
            let (timestamp, timestampOverflow) = UInt64(bitPattern: sqlite3_column_int64(sql, 3)).addingReportingOverflow(UInt64(NSTimeIntervalSince1970))
            
            peers.append(System.PeerBlob.btc(address: address,
                                             port: port,
                                             services: services,
                                             timestamp: timestampOverflow ? nil : UInt32(timestamp)))
        }
        
        if sqlite3_errcode(self.db) != SQLITE_DONE { print(String(cString: sqlite3_errmsg(self.db))) }
        return peers
    }
}
