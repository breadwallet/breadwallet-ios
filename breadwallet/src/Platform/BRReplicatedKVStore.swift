//
//  BRReplicatedKVStore.swift
//  BreadWallet
//
//  Created by Samuel Sutch on 8/10/16.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
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

public enum BRReplicatedKVStoreError: Error {
    case sqLiteError
    case replicationError
    case alreadyReplicating
    case conflict
    case notFound
    case invalidKey
    case unknown
}

public enum BRRemoteKVStoreError: Error {
    case notFound
    case conflict
    case tombstone
    case unknown
}

/// An interface to a remote key value store which utilizes optimistic-locking for concurrency control
public protocol BRRemoteKVStoreAdaptor {
    /// Fetch the version of the key from the remote store
    /// returns a tuple of (remoteVersion, remoteDate, remoteErr?)
    func ver(key: String, completionFunc: @escaping (UInt64, Date, BRRemoteKVStoreError?) -> ())
    
    /// Save a new version of the key to the remote server
    /// takes the value and current remote version (zero if creating)
    /// returns a tuple of (remoteVersion, remoteDate, remoteErr?)
    func put(_ key: String, value: [UInt8], version: UInt64,
             completionFunc: @escaping (UInt64, Date, BRRemoteKVStoreError?) -> ())
    
    /// Marks a key as deleted on the remote server
    /// takes the current remote version (which same as put() must match the current servers time)
    /// returns a tuple of (remoteVersion, remoteDate, remoteErr?)
    func del(_ key: String, version: UInt64, completionFunc: @escaping (UInt64, Date, BRRemoteKVStoreError?) -> ())
    
    /// Get a key from the server
    /// takes the current remote version (which may optionally be zero to fetch the newest version)
    /// returns a tuple of (remoteVersion, remoteDate, remoteBytes, remoteErr?)
    func get(_ key: String, version: UInt64,
             completionFunc: @escaping (UInt64, Date, [UInt8], BRRemoteKVStoreError?) -> ())
    
    /// Get a list of all keys on the remote server
    /// returns a list of tuples of (remoteKey, remoteVersion, remoteDate, remoteErr?)
    func keys(_ completionFunc: @escaping ([(String, UInt64, Date, BRRemoteKVStoreError?)], BRRemoteKVStoreError?) -> ())
}

private func dispatch_sync_throws(_ queue: DispatchQueue, f: () throws -> ()) throws {
    var e: Error? = nil
    queue.sync {
        do {
            try f()
        } catch let caught {
            e = caught
        }
    }
    if let e = e {
        throw e
    }
}

/// A key value store which can replicate its data to remote servers that utilizes optimistic locking for local
/// concurrency control
open class BRReplicatedKVStore: NSObject {
    fileprivate var db: OpaquePointer? = nil // sqlite3*
    fileprivate(set) var key: BRKey
    fileprivate(set) var remote: BRRemoteKVStoreAdaptor
    fileprivate(set) var syncRunning = false
    fileprivate var dbQueue: DispatchQueue
    fileprivate let keyRegex = try! NSRegularExpression(pattern: "^[^_][\\w-]{1,255}$", options: [])
    
    /// Whether or not we immediately sync a key when set() or del() is called
    /// by default it is off because only one sync can run at a time, and if you set or del a lot of keys
    /// most operations will err out
    open var syncImmediately = false
    
    /// Whether or not the data replicated to the serve is encrypted. Default value should always be yes,
    /// this property should only be used for testing with non-sensitive data
    open var encryptedReplication = true
    
    
    /// Whether the data is encrypted at rest on disk
    open var encrypted = true
    
    fileprivate var path: URL {
        let fm = FileManager.default
        let docsUrl = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let bundleDirUrl = docsUrl.appendingPathComponent("kvstore.sqlite3")
        return bundleDirUrl
    }
    
    init(encryptionKey: BRKey, remoteAdaptor: BRRemoteKVStoreAdaptor) throws {
        key = encryptionKey
        remote = remoteAdaptor
        dbQueue = DispatchQueue(label: "com.voisine.breadwallet.kvDBQueue", attributes: [])
        super.init()
        try self.openDatabase()
        try self.migrateDatabase()
    }
    
    /// Removes the entire database all at once. One must call openDatabase() and migrateDatabase()
    /// if one wishes to use this instance again after calling this
    open func rmdb() throws {
        try dispatch_sync_throws(dbQueue) {
            try self.checkErr(sqlite3_close(self.db), s: "rmdb - close")
            try FileManager.default.removeItem(at: self.path)
            self.db = nil
        }
    }
    
    /// Creates the internal database connection. Called automatically in init()
    func openDatabase() throws {
        try dispatch_sync_throws(dbQueue) {
            if self.db != nil {
                print("Database already open")
                throw BRReplicatedKVStoreError.sqLiteError
            }
            try self.checkErr(sqlite3_open_v2(
                self.path.absoluteString, &self.db,
                SQLITE_OPEN_FULLMUTEX | SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE, nil
            ), s: "opening db")
            self.log("opened DB at \(self.path.absoluteString)")
        }
    }
    
    deinit {
        sqlite3_close(db)
    }
    
    /// Creates the local database structure. Called automatically in init()
    func migrateDatabase() throws {
        try dispatch_sync_throws(dbQueue) {
            let commands = [
                "CREATE TABLE IF NOT EXISTS dbversion (ver INT NOT NULL PRIMARY KEY ON CONFLICT REPLACE);",
                "INSERT INTO dbversion (ver) VALUES (1);",
                "CREATE TABLE IF NOT EXISTS kvstore (" +
                "   version         BIGINT  NOT NULL, " +
                "   remote_version  BIGINT  NOT NULL DEFAULT 0, " +
                "   key             TEXT    NOT NULL, " +
                "   value           BLOB    NOT NULL, " +
                "   thetime         BIGINT  NOT NULL, " + // server unix timestamp in MS
                "   deleted         BOOL    NOT NULL, " +
                "   PRIMARY KEY (key, version) " +
                ");"
            ];
            for cmd in commands {
                var stmt: OpaquePointer? = nil
                defer {
                    sqlite3_finalize(stmt)
                }
                try self.checkErr(sqlite3_prepare_v2(self.db, cmd, -1, &stmt, nil), s: "migrate prepare")
                try self.checkErr(sqlite3_step(stmt), s: "migrate stmt exec")
            }
        }
    }
    
    // get a key from the local database, optionally specifying a version
    func get(_ key: String, version: UInt64 = 0) throws -> (UInt64, Date, Bool, [UInt8]) {
        try checkKey(key)
        var ret = [UInt8]()
        var curVer: UInt64 = 0
        var deleted = false
        var time = Date(timeIntervalSince1970: Double())
        try txn {
            if version == 0 {
                (curVer, _) = try self._localVersion(key)
            } else {
                // check for the existence of such a version
                var vStmt: OpaquePointer? = nil
                defer {
                    sqlite3_finalize(vStmt)
                }
                try self.checkErr(sqlite3_prepare_v2(
                    self.db, "SELECT version FROM kvstore WHERE key = ? AND version = ? ORDER BY version DESC LIMIT 1",
                    -1, &vStmt, nil
                ), s: "get - get version - prepare")
                sqlite3_bind_text(vStmt, 1, NSString(string: key).utf8String, -1, nil)
                sqlite3_bind_int64(vStmt, 2, Int64(version))
                try self.checkErr(sqlite3_step(vStmt), s: "get - get version - exec", r: SQLITE_ROW)
                curVer = UInt64(sqlite3_column_int64(vStmt, 0))
            }
            if curVer == 0 {
                throw BRReplicatedKVStoreError.notFound
            }
            
            
            self.log("GET key: \(key) ver: \(curVer)")
            var stmt: OpaquePointer? = nil
            defer {
                sqlite3_finalize(stmt)
            }
            try self.checkErr(sqlite3_prepare_v2(
                self.db, "SELECT value, length(value), thetime, deleted FROM kvstore WHERE key=? AND version=? LIMIT 1",
                -1, &stmt, nil
            ), s: "get - prepare stmt")
            sqlite3_bind_text(stmt, 1, NSString(string: key).utf8String, -1, nil)
            sqlite3_bind_int64(stmt, 2, Int64(curVer))
            try self.checkErr(sqlite3_step(stmt), s: "get - step stmt", r: SQLITE_ROW)
            let blob = sqlite3_column_blob(stmt, 0)
            let blobLength = sqlite3_column_int(stmt, 1)
            time = Date.withMsTimestamp(UInt64(sqlite3_column_int64(stmt, 2)))
            deleted = sqlite3_column_int(stmt, 3) > 0
            ret = Array(UnsafeBufferPointer<UInt8>(start: blob?.assumingMemoryBound(to: UInt8.self), count: Int(blobLength)))
        }
        return (curVer, time, deleted, (encrypted ? try decrypt(ret) : ret))
    }
    
    /// Set the value of a key locally in the database. If syncImmediately is true (the default) then immediately
    /// after successfully saving locally, replicate to server. The `localVer` key must be the same as is currently
    /// stored in the database. To create a new key, pass `0` as `localVer`
    func set(_ key: String, value: [UInt8], localVer: UInt64) throws -> (UInt64, Date) {
        try checkKey(key)
        let (newVer, time) = try _set(key, value: value, localVer: localVer)
        if syncImmediately {
            try syncKey(key) { _ in
                self.log("SET key synced: \(key)")
            }
        }
        return (newVer, time)
    }
    
    fileprivate func _set(_ key: String, value: [UInt8], localVer: UInt64) throws -> (UInt64, Date) {
        var newVer: UInt64 = 0
        var time = Date()
        try txn {
            let (curVer, _) = try self._localVersion(key)
            if curVer != localVer {
                self.log("set key \(key) conflict: version \(localVer) != current version \(curVer)")
                throw BRReplicatedKVStoreError.conflict
            }
            self.log("SET key: \(key) ver: \(curVer)")
            newVer = curVer + 1
            let encryptedData = self.encrypted ? try self.encrypt(value) : value
            var stmt: OpaquePointer? = nil
            defer {
                sqlite3_finalize(stmt)
            }
            try self.checkErr(sqlite3_prepare_v2(self.db,
                "INSERT INTO kvstore (version, key, value, thetime, deleted) " +
                "VALUES (?, ?, ?, ?, ?)", -1, &stmt, nil
                ), s: "set - prepare stmt")
            sqlite3_bind_int64(stmt, 1, Int64(newVer))
            sqlite3_bind_text(stmt, 2, NSString(string: key).utf8String, -1, nil)
            sqlite3_bind_blob(stmt, 3, encryptedData, Int32(encryptedData.count), nil)
            sqlite3_bind_int64(stmt, 4, Int64(time.msTimestamp()))
            sqlite3_bind_int(stmt, 5, 0)
            try self.checkErr(sqlite3_step(stmt), s: "set - step stmt")
        }
        return (newVer, time)
    }
    
    /// Mark a key as removed locally. If syncImmediately is true (the defualt) then immediately mark the key
    /// as removed on the server as well. `localVer` must match the most recent version in the local database.
    func del(_ key: String, localVer: UInt64) throws -> (UInt64, Date) {
        try checkKey(key)
        let (newVer, time) = try _del(key, localVer: localVer)
        if syncImmediately {
            try syncKey(key) { _ in
                self.log("DEL key synced: \(key)")
            }
        }
        return (newVer, time)
    }
    
    func _del(_ key: String, localVer: UInt64) throws -> (UInt64, Date) {
        if localVer == 0 {
            throw BRReplicatedKVStoreError.notFound
        }
        var newVer: UInt64 = 0
        var time = Date()
        try txn {
            let (curVer, _) = try self._localVersion(key)
            if curVer != localVer {
                self.log("del key \(key) conflict: version \(localVer) != current version \(curVer)")
                throw BRReplicatedKVStoreError.conflict
            }
            self.log("DEL key: \(key) ver: \(curVer)")
            newVer = curVer + 1
            var stmt: OpaquePointer? = nil
            defer {
                sqlite3_finalize(stmt)
            }
            try self.checkErr(sqlite3_prepare_v2(
                self.db, "INSERT INTO kvstore (version, key, value, thetime, deleted) " +
                         "SELECT ?, key, value, ?, ? " +
                         "FROM kvstore WHERE key=? AND version=?",
                -1, &stmt, nil
            ), s: "del - prepare stmt")
            sqlite3_bind_int64(stmt, 1, Int64(newVer))
            sqlite3_bind_int64(stmt, 2, Int64(time.msTimestamp()))
            sqlite3_bind_int(stmt, 3, 1)
            sqlite3_bind_text(stmt, 4, NSString(string: key).utf8String, -1, nil)
            sqlite3_bind_int64(stmt, 5, Int64(curVer))
            try self.checkErr(sqlite3_step(stmt), s: "del - exec stmt")
        }
        return (newVer, time)
    }
    
    /// Gets the local version of the provided key, or 0 if it doesn't exist
    func localVersion(_ key: String) throws -> (UInt64, Date) {
        try checkKey(key)
        var retVer: UInt64 = 0
        var retTime = Date(timeIntervalSince1970: Double())
        try txn {
            (retVer, retTime) = try self._localVersion(key)
        }
        return (retVer, retTime)
    }
    
    func _localVersion(_ key: String) throws -> (UInt64, Date) {
        var stmt: OpaquePointer? = nil
        defer {
            sqlite3_finalize(stmt)
        }
        try self.checkErr(sqlite3_prepare_v2(
            self.db, "SELECT version, thetime FROM kvstore WHERE key = ? ORDER BY version DESC LIMIT 1", -1,
            &stmt, nil
        ), s: "get version - prepare")
        sqlite3_bind_text(stmt, 1, NSString(string: key).utf8String, -1, nil)
        try self.checkErr(sqlite3_step(stmt), s: "get version - exec", r: SQLITE_ROW)
        return (
            UInt64(sqlite3_column_int64(stmt, 0)),
            Date.withMsTimestamp(UInt64(sqlite3_column_int64(stmt, 1)))
        )
    }
    
    /// Get the remote version for the key for the most recent local version of the key, if stored.
    // If local key doesn't exist, return 0
//    func remoteVersion(key: String) throws -> UInt64 {

////        return 0
//    }
    func remoteVersion(_ key: String) throws -> Int { // this would be UInt64.. but it makes the compiler crash
        try checkKey(key)
        var ret: UInt64 = 0
        try txn {
            var stmt: OpaquePointer? = nil
            defer {
                sqlite3_finalize(stmt)
            }
            try self.checkErr(sqlite3_prepare_v2(
                self.db, "SELECT remote_version FROM kvstore WHERE key = ? ORDER BY version DESC LIMIT 1", -1, &stmt, nil
                ), s: "get remote version - prepare")
            sqlite3_bind_text(stmt, 1, NSString(string: key).utf8String, -1, nil)
            try self.checkErr(sqlite3_step(stmt), s: "get remote version - exec", r: SQLITE_ROW)
            ret = UInt64(sqlite3_column_int64(stmt, 0))
        }
        return Int(ret)
    }
    
    /// Record the remote version for the object in a new version of the local key
    func setRemoteVersion(key: String, localVer: UInt64, remoteVer: UInt64) throws -> (UInt64, Date) {
        try checkKey(key)
        if localVer < 1 {
            throw BRReplicatedKVStoreError.conflict // setRemoteVersion can't be used for creates
        }
        var newVer: UInt64 = 0
        var time = Date()
        try txn {
            let (curVer, _) = try self._localVersion(key)
            if curVer != localVer {
                self.log("set remote version key \(key) conflict: version \(localVer) != current version \(curVer)")
                throw BRReplicatedKVStoreError.conflict
            }
            self.log("SET REMOTE VERSION: \(key) ver: \(localVer) remoteVer=\(remoteVer)")
            newVer = curVer + 1
            var stmt: OpaquePointer? = nil
            defer {
                sqlite3_finalize(stmt)
            }
            try self.checkErr(sqlite3_prepare_v2(
                self.db, "INSERT INTO kvstore (version, key, value, thetime, deleted, remote_version) " +
                         "SELECT               ?,       key, value, ?,       deleted, ? " +
                         "FROM kvstore WHERE key=? AND version=?",
                -1, &stmt, nil
            ), s: "update remote version - prepare stmt")
            sqlite3_bind_int64(stmt, 1, Int64(newVer))
            sqlite3_bind_int64(stmt, 2, Int64(time.msTimestamp()))
            sqlite3_bind_int64(stmt, 3, Int64(remoteVer))
            sqlite3_bind_text(stmt, 4, NSString(string: key).utf8String, -1, nil)
            sqlite3_bind_int64(stmt, 5, Int64(curVer))
            try self.checkErr(sqlite3_step(stmt), s: "update remote - exec stmt")
        }
        return (newVer, time)
    }
    
    /// Get a list of (key, localVer, localTime, remoteVer, deleted)
    func localKeys() throws -> [(String, UInt64, Date, UInt64, Bool)] {
        var ret = [(String, UInt64, Date, UInt64, Bool)]()
        try txn {
            var stmt: OpaquePointer? = nil
            defer {
                sqlite3_finalize(stmt)
            }
            try self.checkErr(sqlite3_prepare_v2(self.db,
                "SELECT kvs.key, kvs.version, kvs.thetime, kvs.remote_version, kvs.deleted " +
                "FROM kvstore kvs " +
                "INNER JOIN ( " +
                "   SELECT MAX(version) AS latest_version, key " +
                "   FROM kvstore " +
                "   GROUP BY key " +
                ") vermax " +
                "ON kvs.version = vermax.latest_version " +
                "AND kvs.key = vermax.key", -1, &stmt, nil),
                              s: "local keys - prepare stmt")
            while sqlite3_step(stmt) == SQLITE_ROW {
                let key = sqlite3_column_text(stmt, 0)
                let ver = sqlite3_column_int64(stmt, 1)
                let date = sqlite3_column_int64(stmt, 2)
                let rver = sqlite3_column_int64(stmt, 3)
                let del = sqlite3_column_int(stmt, 4)
                if let key = key {
                    ret.append((
                        String(cString: key),
                        UInt64(ver),
                        Date.withMsTimestamp(UInt64(date)),
                        UInt64(rver),
                        del > 0
                    ))
                }
            }
        }
        return ret
    }
    
    /// Sync all keys to and from the remote kv store adaptor
    func syncAllKeys(_ completionHandler: @escaping (BRReplicatedKVStoreError?) -> ()) {
        // update all keys locally and on the remote server, replacing missing keys
        //
        // 1. get a list of all keys from the server
        // 2. for keys that we don't have, add em
        // 3. for keys that we do have, sync em
        // 4. for keys that they don't have that we do, upload em
        if syncRunning {
            DispatchQueue.main.async(execute: { 
                completionHandler(.alreadyReplicating)
            })
            return
        }
        syncRunning = true
        let startTime = Date()
        remote.keys { (keyData, err) in
            if let err = err {
                self.log("Error fetching remote key data: \(err)")
                self.syncRunning = false
                return completionHandler(.replicationError)
            }
            var localKeyData: [(String, UInt64, Date, UInt64, Bool)]
            do {
                localKeyData = try self.localKeys()
            } catch let e {
                self.syncRunning = false
                self.log("Error getting local key data: \(e)")
                return completionHandler(.replicationError)
            }
            let allRemoteKeys = Set(keyData.map { e in return e.0 })
            var allKeyData = keyData
            for k in localKeyData {
                if !allRemoteKeys.contains(k.0) {
                    // server is missing a key that we have
                    allKeyData.append((k.0, 0, Date(timeIntervalSince1970: Double()), nil))
                }
            }
            
            self.log("Syncing \(allKeyData.count) keys")
            var failures = 0
            let q = DispatchQueue(label: "com.voisine.breadwallet.kvSyncQueue", attributes: DispatchQueue.Attributes.concurrent)
            let grp = DispatchGroup()
            let seph = DispatchSemaphore(value: 10)
            
            grp.enter()
            q.async {
                q.async {
                    for k in allKeyData {
                        _ = seph.wait(timeout: DispatchTime.distantFuture)
                        q.async(group: grp) {
                            do {
                                try self._syncKey(k.0, remoteVer: k.1, remoteTime: k.2, remoteErr: k.3,
                                    completionHandler: { (err) in
                                        if err != nil {
                                            failures += 1
                                        }
                                        seph.signal()
                                })
                            } catch {
                                failures += 1
                                seph.signal()
                            }
                        }
                    }
                    grp.leave()
                }
                _ = grp.wait(timeout: DispatchTime.distantFuture)
                DispatchQueue.main.async {
                    self.syncRunning = false
                    self.log("Finished syncing in \(Date().timeIntervalSince(startTime))")
                    completionHandler(failures > 0 ? .replicationError : nil)
                }
            }
        }
    }
    
    /// Sync an individual key. Normally this is only called internally and you should call syncAllKeys
    func syncKey(_ key: String, remoteVersion: UInt64? = nil, remoteTime: Date? = nil,
                 remoteErr: BRRemoteKVStoreError? = nil, completionHandler: @escaping (BRReplicatedKVStoreError?) -> ()) throws {
        try checkKey(key)
        if syncRunning {
            throw BRReplicatedKVStoreError.alreadyReplicating
        }
        syncRunning = true
        let myCompletionHandler: (_ e: BRReplicatedKVStoreError?) -> () = { e in
            completionHandler(e)
            self.syncRunning = false
        }
        if let remoteVersion = remoteVersion, let remoteTime = remoteTime {
            try _syncKey(key, remoteVer: remoteVersion, remoteTime: remoteTime,
                         remoteErr: remoteErr, completionHandler: myCompletionHandler)
        } else {
            remote.ver(key: key) { (remoteVer, remoteTime, err) in
                _ = try? self._syncKey(key, remoteVer: remoteVer, remoteTime: remoteTime,
                                       remoteErr: err, completionHandler: myCompletionHandler)
            }
        }
    }
    
    // the syncKey kernel - this is provided so syncAllKeys can provide get a bunch of key versions at once
    // and fan out the _syncKey operations
    fileprivate func _syncKey(_ key: String, remoteVer: UInt64, remoteTime: Date, remoteErr: BRRemoteKVStoreError?,
                          completionHandler: @escaping (BRReplicatedKVStoreError?) -> ()) throws {
        // this is a basic last-write-wins strategy. data loss is possible but in general
        // we will attempt to sync before making any local modifications to the data
        // and concurrency will be so low that we don't really need a fancier solution than this.
        // the strategy is:
        //
        // 1. get the remote version. this is our "lock"
        // 2. along with the remote version will come the last-modified date of the remote object
        // 3. if their last-modified date is newer than ours, overwrite ours
        // 4. if their last-modified date is older than ours, overwrite theirs
        
        if !syncRunning {
            throw BRReplicatedKVStoreError.unknown // how did we get here
        }
        
        // one optimization is we keep the remote version on the most recent local version, if they match,
        // there is nothing to do
        let recordedRemoteVersion = try UInt64(remoteVersion(key))
        if remoteErr != .some(.notFound) && remoteVer > 0 && recordedRemoteVersion == remoteVer {
            log("Remote version of key \(key) is the same as the one we have")
            return completionHandler(nil) // this key is already up to date
        }
        
        var localVer: UInt64
        var localTime: Date
        var localDeleted: Bool
        var localValue: [UInt8]
        do {
            (localVer, localTime, localDeleted, localValue) = try get(key)
            localValue = self.encryptedReplication ? try encrypt(localValue) : localValue
        } catch BRReplicatedKVStoreError.notFound {
            // missing key locally
            (localVer, localTime, localDeleted, localValue) = (0, Date(timeIntervalSince1970: Double()), false, [])
        }
        let (lt, rt) = (localTime.msTimestamp(), remoteTime.msTimestamp())
        
        switch remoteErr {
        case nil, .some(.tombstone), .some(.notFound):
            if localDeleted && remoteErr == .some(.tombstone) { // was removed on both server and locally
                log("Local key \(key) was deleted, and so was the remote key")
                do {
                    _ = try self.setRemoteVersion(key: key, localVer: localVer, remoteVer: remoteVer)
                } catch let e where e is BRReplicatedKVStoreError {
                    return completionHandler((e as! BRReplicatedKVStoreError))
                } catch {
                    return completionHandler(.replicationError)
                }
                return completionHandler(nil)
            }
            
            if lt > rt || lt == rt { // local is newer (or a tiebreaker)
                if localDeleted {
                    log("Local key \(key) was deleted, removing remotely...")
                    self.remote.del(key, version: remoteVer, completionFunc: { (newRemoteVer, _, delErr) in
                        if delErr == .some(.notFound) {
                            self.log("Local key \(key) was already missing on the server. Ignoring")
                            return completionHandler(nil)
                        }
                        if let delErr = delErr {
                            self.log("Error deleting remote version for key \(key), error: \(delErr)")
                            return completionHandler(.replicationError)
                        }
                        do {
                            _ = try self.setRemoteVersion(key: key, localVer: localVer, remoteVer: newRemoteVer)
                        } catch let e where e is BRReplicatedKVStoreError {
                            return completionHandler((e as! BRReplicatedKVStoreError))
                        } catch {
                            return completionHandler(.replicationError)
                        }
                        self.log("Local key \(key) removed on server")
                        completionHandler(nil)
                    })
                } else {
                    log("Local key \(key) is newer remoteVer=\(remoteVer), updating remotely...")
                    // if the remote version is zero it means it doesnt yet exist on the server. set the remote version 
                    // to "1" to create the key on the server
                    let useRemoteVer = remoteVer == 0 || remoteVer < recordedRemoteVersion ? 1 : remoteVer
                    self.remote.put(key, value: localValue, version: useRemoteVer,
                                    completionFunc: { (newRemoteVer, remoteDate, putErr) in
                        if let putErr = putErr {
                            self.log("Error updating remote version for key \(key), newRemoteVer=\(newRemoteVer) error: \(putErr)")
                            return completionHandler(.replicationError)
                        }
                        do {
                            _ = try self.setRemoteVersion(key: key, localVer: localVer, remoteVer: newRemoteVer)
                        } catch let e where e is BRReplicatedKVStoreError {
                            return completionHandler((e as! BRReplicatedKVStoreError))
                        } catch {
                            return completionHandler(.replicationError)
                        }
                        self.log("Local key \(key) updated on server")
                        completionHandler(nil)
                    })
                }
            } else {
                // local is out-of-date
                if remoteErr == .some(.tombstone) {
                    // remote is deleted
                    log("Remote key \(key) deleted, removing locally")
                    do {
                        let (newLocalVer, _) = try self._del(key, localVer: localVer)
                        _ = try self.setRemoteVersion(key: key, localVer: newLocalVer, remoteVer: remoteVer)
                    } catch BRReplicatedKVStoreError.notFound {
                        // well a deleted key isn't found, so why do we care
                    } catch let e where e is BRReplicatedKVStoreError {
                        return completionHandler((e as! BRReplicatedKVStoreError))
                    } catch {
                        return completionHandler(.replicationError)
                    }
                    log("Remote key \(key) was removed locally")
                    completionHandler(nil)
                } else {
                    log("Remote key \(key) is newer, fetching...")
                    // get the remote version
                    self.remote.get(key, version: remoteVer, completionFunc: { (newRemoteVer, _, remoteData, getErr) in
                        if let getErr = getErr {
                            self.log("Error fetching the remote value for key \(getErr), error: \(getErr)")
                            return completionHandler(.replicationError)
                        }
                        do {
                            let decryptedValue = self.encryptedReplication ? try self.decrypt(remoteData) : remoteData
                            let (newLocalVer, _) = try self._set(key, value: decryptedValue, localVer: localVer)
                            _ = try self.setRemoteVersion(key: key, localVer: newLocalVer, remoteVer: newRemoteVer)
                        } catch let e where e is BRReplicatedKVStoreError {
                            return completionHandler((e as! BRReplicatedKVStoreError))
                        } catch {
                            return completionHandler(.replicationError)
                        }
                        self.log("Updated local key \(key)")
                        completionHandler(nil)
                    })
                }
            }
        default:
            log("Error fetching remote version for key \(key), error: \(remoteErr)")
            completionHandler(.replicationError)
        }
    }
    
    // execute a function inside a transaction, if that function throws then rollback, otherwise commit
    // calling txn() from within a txn function will deadlock
    fileprivate func txn(_ fn: () throws -> ()) throws {
        try dispatch_sync_throws(dbQueue) {
            var beginStmt: OpaquePointer? = nil
            var finishStmt: OpaquePointer? = nil
            defer {
                sqlite3_finalize(beginStmt)
                sqlite3_finalize(finishStmt)
            }
            try self.checkErr(sqlite3_prepare_v2(self.db, "BEGIN", -1, &beginStmt, nil), s: "txn - prepare begin")
            try self.checkErr(sqlite3_step(beginStmt), s: "txn - exec begin begin")
            do {
                try fn()
            } catch let e {
                try self.checkErr(sqlite3_prepare_v2(
                    self.db, "ROLLBACK" , -1, &finishStmt, nil), s: "txn - prepare rollback")
                try self.checkErr(sqlite3_step(finishStmt), s: "txn - execute rollback")
                throw e
            }
            try self.checkErr(sqlite3_prepare_v2(self.db, "COMMIT", -1, &finishStmt, nil), s: "txn - prepare commit")
            try self.checkErr(sqlite3_step(finishStmt), s: "txn - execute commit")
        }
    }
    
    // ensure the sqlite3 error code is an acceptable one (or that its the one you provide as `r`
    // this MUST be called from within the dbQueue
    fileprivate func checkErr(_ e: Int32, s: String, r: Int32 = SQLITE_NULL) throws {
        if (r == SQLITE_NULL && (e != SQLITE_OK && e != SQLITE_DONE && e != SQLITE_ROW))
            && (e != SQLITE_NULL && e != r) {
            let es = NSString(cString: sqlite3_errstr(e), encoding: String.Encoding.utf8.rawValue)
            let em = NSString(cString: sqlite3_errmsg(db), encoding: String.Encoding.utf8.rawValue)
            log("\(s): errcode=\(e) errstr=\(es) errmsg=\(em)")
            throw BRReplicatedKVStoreError.sqLiteError
        }
    }
    
    // validates the key. keys can not start with a _
    fileprivate func checkKey(_ key: String) throws {
        let m = keyRegex.matches(in: key, options: [], range: NSMakeRange(0, key.characters.count))
        if m.count != 1 {
            throw BRReplicatedKVStoreError.invalidKey
        }
    }
    
    // encrypt some data using self.key
    fileprivate func encrypt(_ data: [UInt8]) throws -> [UInt8] {
        guard let sk = key.secretKey else {
            throw BRReplicatedKVStoreError.unknown
        }
        let inData = UnsafePointer<UInt8>(data)
        let nonce = genNonce()
        var null =  CChar(0)
        let outSize = chacha20Poly1305AEADEncrypt(nil, 0, sk, nonce, inData, data.count, &null, 0)
        var outData = [UInt8](repeating: 0, count: outSize)
        chacha20Poly1305AEADEncrypt(&outData, outSize, sk, nonce, inData, data.count, &null, 0)
        return nonce + outData
    }
    
    // decrypt some data using self.key
    fileprivate func decrypt(_ data: [UInt8]) throws -> [UInt8] {
        guard let sk = key.secretKey else {
            throw BRReplicatedKVStoreError.unknown
        }
        let nonce = Array(data[data.startIndex...data.startIndex.advanced(by: 12)])
        let inData = Array(data[data.startIndex.advanced(by: 12)...(data.endIndex-1)])
        var null =  CChar(0)
        let outSize = chacha20Poly1305AEADDecrypt(nil, 0, sk, nonce, inData, inData.count, &null, 0)
        var outData = [UInt8](repeating: 0, count: outSize)
        chacha20Poly1305AEADDecrypt(&outData, outSize, sk, nonce, inData, inData.count, &null, 0)
        return outData
    }
    
    // generate a nonce using microseconds-since-epoch
    fileprivate func genNonce() -> [UInt8] {
        var tv = timeval()
        gettimeofday(&tv, nil)
        var t = UInt64(tv.tv_usec) * 1_000_000 + UInt64(tv.tv_usec)
        let p = [UInt8](repeating: 0, count: 4)
//        let dat = Data(bytes: &t, count: MemoryLayout<UInt64>.size).bytes.bindMemory(to: UInt8.self, capacity: Data(bytes: &t, count: MemoryLayout<UInt64>.size).count)
        return Data(bytes: &t, count: MemoryLayout<UInt64>.size).withUnsafeBytes { (dat: UnsafePointer<UInt8>) -> [UInt8] in
            let buf = UnsafeBufferPointer(start: dat, count: MemoryLayout<UInt64>.size)
            return p + Array(buf)
        }
    }
    
    fileprivate func log(_ s: String) {
        print("[KVStore] \(s)")
    }
}

// MARK: - Objective-C compatability layer

@objc open class BRKVStoreObject: NSObject {
    open var version: UInt64
    open var lastModified: Date
    open var deleted: Bool
    open var key: String
    
    fileprivate var _data: Data? = nil
    
    var data: Data {
        get {
            return getData() ?? _data ?? Data() // allow subclasses to override the data that is retrieved
        }
        set(v) {
            _data = v
            dataWasSet(v)
        }
    }
    
    init(key: String, version: UInt64, lastModified: Date, deleted: Bool, data: Data) {
        self.version = version
        self.key = key
        self.lastModified = lastModified
        self.deleted = deleted
        super.init()
        self.data = data
    }
    
    func getData() -> Data? { return nil }
    
    func dataWasSet(_ value: Data) { }
}

extension BRReplicatedKVStore {
    @objc public func get(_ key: String) throws -> BRKVStoreObject {
        let (v, d, r, b) = try get(key)
        return BRKVStoreObject(key: key, version: v, lastModified: d, deleted: r,
                               data: Data(bytes: UnsafePointer<UInt8>(b), count: b.count))
    }
    
    @objc public func set(_ object: BRKVStoreObject) throws -> BRKVStoreObject {
        let dat = object.data
        var bytes = [UInt8](repeating: 0, count: dat.count)
        (dat as NSData).getBytes(&bytes, length: dat.count)
        (object.version, object.lastModified) = try set(object.key, value: bytes, localVer: object.version)
        return object
    }
    
    @objc public func del(_ object: BRKVStoreObject) throws -> BRKVStoreObject {
        (object.version, object.lastModified) = try del(object.key, localVer: object.version)
        object.deleted = true
        return object
    }
    
    @objc public func sync(_ completionFunc: @escaping (NSError?) -> ()) {
        syncAllKeys { (e) in
            completionFunc(
                NSError(domain: "KV_STORE", code: -1001, userInfo: [NSLocalizedDescriptionKey: e.debugDescription])
            )
        }
    }
}
