//
//  BRReplicatedKVStoreTests.swift
//  breadwallet
//
//  Created by Samuel Sutch on 12/7/16.
//  Copyright © 2016-2019 Breadwinner AG. All rights reserved.
//

import XCTest
@testable import breadwallet
import BRCrypto

class BRReplicatedKVStoreTestAdapter: BRRemoteKVStoreAdaptor {
    let testCase: XCTestCase
    var db = [String: (UInt64, Date, [UInt8], Bool)]()
    
    init(testCase: XCTestCase) {
        self.testCase = testCase
    }
    
    func keys(_ completionFunc: @escaping ([(String, UInt64, Date, BRRemoteKVStoreError?)], BRRemoteKVStoreError?) -> ()) {
        print("[TestRemoteKVStore] KEYS")
        DispatchQueue.main.async {
            let res = self.db.map { (t) -> (String, UInt64, Date, BRRemoteKVStoreError?) in
                return (t.0, t.1.0, t.1.1, t.1.3 ? BRRemoteKVStoreError.tombstone : nil)
            }
            completionFunc(res, nil)
        }
    }
    
    func ver(key: String, completionFunc: @escaping (UInt64, Date, BRRemoteKVStoreError?) -> ()) {
        print("[TestRemoteKVStore] VER \(key)")
        DispatchQueue.main.async {
            guard let obj = self.db[key] else {
                return completionFunc(0, Date(), .notFound)
            }
            completionFunc(obj.0, obj.1, obj.3 ? .tombstone : nil)
        }
    }
    
    func get(_ key: String, version: UInt64, completionFunc: @escaping (UInt64, Date, [UInt8], BRRemoteKVStoreError?) -> ()) {
        print("[TestRemoteKVStore] GET \(key) \(version)")
        DispatchQueue.main.async {
            guard let obj = self.db[key] else {
                return completionFunc(0, Date(), [], .notFound)
            }
            if version != obj.0 {
                return completionFunc(0, Date(), [], .conflict)
            }
            completionFunc(obj.0, obj.1, obj.2, obj.3 ? .tombstone : nil)
        }
    }
    
    func put(_ key: String, value: [UInt8], version: UInt64, completionFunc: @escaping (UInt64, Date, BRRemoteKVStoreError?) -> ()) {
        print("[TestRemoteKVStore] PUT \(key) \(version)")
        DispatchQueue.main.async {
            guard let obj = self.db[key] else {
                if version != 1 {
                    return completionFunc(1, Date(), .notFound)
                }
                let newObj = (UInt64(1), Date(), value, false)
                self.db[key] = newObj
                return completionFunc(1, newObj.1, nil)
            }
            if version != obj.0 {
                return completionFunc(0, Date(), .conflict)
            }
            let newObj = (obj.0 + 1, Date(), value, false)
            self.db[key] = newObj
            completionFunc(newObj.0, newObj.1, nil)
        }
    }
    
    func del(_ key: String, version: UInt64, completionFunc: @escaping (UInt64, Date, BRRemoteKVStoreError?) -> ()) {
        print("[TestRemoteKVStore] DEL \(key) \(version)")
        DispatchQueue.main.async {
            guard let obj = self.db[key] else {
                return completionFunc(0, Date(), .notFound)
            }
            if version != obj.0 {
                return completionFunc(0, Date(), .conflict)
            }
            let newObj = (obj.0 + 1, Date(), obj.2, true)
            self.db[key] = newObj
            completionFunc(newObj.0, newObj.1, nil)
        }
    }
}

class BRReplicatedKVStoreTest: XCTestCase {
    var store: BRReplicatedKVStore!
    var key: Key {
        let privKey = "S6c56bnXQiBjk9mqSYE7ykVQ7NzrRy"
        return Key.createFromString(asPrivate: privKey)!
    }
    var adapter: BRReplicatedKVStoreTestAdapter!
    
    override func setUp() {
        super.setUp()
        adapter = BRReplicatedKVStoreTestAdapter(testCase: self)
        adapter.db["hello"] = (1, Date(), [0, 1], false)
        adapter.db["removed"] = (2, Date(), [0, 2], true)
        for i in 1...20 {
            adapter.db["testkey-\(i)"] = (1, Date(), [0, UInt8(i + 2)], false)
        }
        store = try! BRReplicatedKVStore(encryptionKey: key, remoteAdaptor: adapter)
        store.encryptedReplication = false
    }
    
    override func tearDown() {
        super.tearDown()
        try! store.rmdb()
        store = nil
    }
    
    func XCTAssertDatabasesAreSynced() { // this only works for keys that are not marked deleted
        var remoteKV = [String: [UInt8]]()
        for (k, v) in adapter.db {
            if !v.3 {
                remoteKV[k] = v.2
            }
        }
        let allLocalKeys = try! store.localKeys()
        var localKV = [String: [UInt8]]()
        for i in allLocalKeys {
            if !i.4 {
                localKV[i.0] = try! store.get(i.0).3
            }
        }
        for (k, v) in remoteKV {
            XCTAssertEqual(v, localKV[k] ?? [])
        }
        for (k, v) in localKV {
            XCTAssertEqual(v, remoteKV[k] ?? [])
        }
    }
    
    // MARK: - local db tests
    
    func testSetLocalDoesntThrow() {
        let (v1, t1) = try! store.set("hello", value: [0, 0, 0], localVer: 0)
        XCTAssertEqual(1, v1)
        XCTAssertNotNil(t1)
    }
    
    func testSetLocalIncrementsVersion() {
        _ = try! store.set("hello", value: [0, 1], localVer: 0)
        XCTAssertEqual(try! store.localVersion("hello").0, 1)
    }
    
    func testSetThenGet() {
        let (v1, t1) = try! store.set("hello", value: [0, 1], localVer: 0)
        let (v, t, d, val) = try! store.get("hello")
        XCTAssertEqual(val, [0, 1])
        XCTAssertEqual(v1, v)
        XCTAssertEqual(t1.timeIntervalSince1970, t.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(d, false)
    }
    
    func testSetThenSetIncrementsVersion() {
        let (v1, _) = try! store.set("hello", value: [0, 1], localVer: 0)
        let (v2, _) = try! store.set("hello", value: [0, 2], localVer: v1)
        XCTAssertEqual(v2, v1 + UInt64(1))
    }
    
    func testSetThenDel() {
        let (v1, _) = try! store.set("hello", value: [0, 1], localVer: 0)
        let (v2, _) = try! store.del("hello", localVer: v1)
        XCTAssertEqual(v2, v1 + UInt64(1))
    }
    
    func testSetThenDelThenGet() {
        let (v1, _) = try! store.set("hello", value: [0, 1], localVer: 0)
        _ = try! store.del("hello", localVer: v1)
        let (v2, _, d, _) = try! store.get("hello")
        XCTAssert(d)
        XCTAssertEqual(v2, v1 + UInt64(1))
    }
    
    func testSetWithIncorrectFirstVersionFails() {
        XCTAssertThrowsError(try store.set("hello", value: [0, 1], localVer: 1))
    }
    
    func testSetWithStaleVersionFails() {
        _ = try! store.set("hello", value: [0, 1], localVer: 0)
        XCTAssertThrowsError(try store.set("hello", value: [0, 1], localVer: 0))
    }
    
    func testGetNonExistentKeyFails() {
        XCTAssertThrowsError(try store.get("hello"))
    }
    
    func testGetNonExistentKeyVersionFails() {
        XCTAssertThrowsError(try store.get("hello", version: 1))
    }
    
    func testGetAllKeys() {
        let (v1, t1) = try! store.set("hello", value: [0, 1], localVer: 0)
        let lst = try! store.localKeys()
        XCTAssertEqual(1, lst.count)
        XCTAssertEqual("hello", lst[0].0)
        XCTAssertEqual(v1, lst[0].1)
        XCTAssertEqual(t1.timeIntervalSince1970, lst[0].2.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(0, lst[0].3)
        XCTAssertEqual(false, lst[0].4)
    }
    
    func testSetRemoteVersion() {
        let (v1, _) = try! store.set("hello", value: [0, 1], localVer: 0)
        let (newV, _) = try! store.setRemoteVersion(key: "hello", localVer: v1, remoteVer: 1)
        XCTAssertEqual(newV, v1 + UInt64(1))
        let rmv = try! store.remoteVersion("hello")
        XCTAssertEqual(rmv, 1)
    }
    
    // MARK: - syncing tests
    
    func testBasicSyncGetAllObjects() {
        let exp = expectation(description: "sync")
        store.syncAllKeys { (err) in
            XCTAssertNil(err)
            exp.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        let allKeys = try! store.localKeys()
        XCTAssertEqual(adapter.db.count - 1, allKeys.count) // minus 1: there is a deleted key that needent be synced
        XCTAssertDatabasesAreSynced()
    }
    
    func testSyncTenTimes() {
        let exp = expectation(description: "sync")
        var n = 10
        var handler: (_ e: Error?) -> () = { e in return }
        handler = { (e: Error?) in
            XCTAssertNil(e)
            if n > 0 {
                self.store.syncAllKeys(handler)
                n -= 1
            } else {
                exp.fulfill()
            }
        }
        handler(nil)
        waitForExpectations(timeout: 2, handler: nil)
        XCTAssertDatabasesAreSynced()
    }
    
    func testSyncAddsLocalKeysToRemote() {
        store.syncImmediately = false
        _ = try! store.set("derp", value: [0, 1], localVer: 0)
        let exp = expectation(description: "sync")
        store.syncAllKeys { (err) in
            XCTAssertNil(err)
            exp.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertEqual(adapter.db["derp"]!.2, [0, 1])
        XCTAssertDatabasesAreSynced()
    }
    
    func testSyncSavesRemoteVersion() {
        let exp = expectation(description: "sync")
        store.syncAllKeys { err in
            XCTAssertNil(err)
            exp.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        let rv = try! store.remoteVersion("hello")
        XCTAssertEqual(adapter.db["hello"]!.0, 1) // it should not have done any mutations
        XCTAssertEqual(adapter.db["hello"]!.0, UInt64(rv)) // only saved the remote version
        XCTAssertDatabasesAreSynced()
    }
    
    func testSyncPreventsAnotherConcurrentSync() {
        let exp1 = expectation(description: "sync")
        let exp2 = expectation(description: "sync2")
        store.syncAllKeys { e in exp1.fulfill() }
        store.syncAllKeys { (e) in
            XCTAssertEqual(e, BRReplicatedKVStoreError.alreadyReplicating)
            exp2.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testLocalDeleteReplicates() {
        let exp1 = expectation(description: "sync1")
        store.syncImmediately = false
        _ = try! store.set("goodbye_cruel_world", value: [0, 1], localVer: 0)
        store.syncAllKeys { (e) in
            XCTAssertNil(e)
            exp1.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertDatabasesAreSynced()
        _ = try! store.del("goodbye_cruel_world",
                           localVer: try! store.localVersion("goodbye_cruel_world").0)
        let exp2 = expectation(description: "sync2")
        store.syncAllKeys { (e) in
            XCTAssertNil(e)
            exp2.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertDatabasesAreSynced()
        XCTAssertEqual(adapter.db["goodbye_cruel_world"]!.3, true)
    }
    
    func testLocalUpdateReplicates() {
        let exp1 = expectation(description: "sync1")
        store.syncImmediately = false
        _ = try! store.set("goodbye_cruel_world", value: [0, 1], localVer: 0)
        store.syncAllKeys { (e) in
            XCTAssertNil(e)
            exp1.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertDatabasesAreSynced()
        _ = try! store.set("goodbye_cruel_world", value: [1, 0, 0, 1],
                           localVer: try! store.localVersion("goodbye_cruel_world").0)
        let exp2 = expectation(description: "sync2")
        store.syncAllKeys { (e) in
            XCTAssertNil(e)
            exp2.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertDatabasesAreSynced()
    }
    
    func testRemoteDeleteReplicates() {
        let exp1 = expectation(description: "sync1")
        store.syncAllKeys { (e) in
            XCTAssertNil(e)
            exp1.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertDatabasesAreSynced()
        adapter.db["hello"]?.0 += 1
        adapter.db["hello"]?.1 = Date()
        adapter.db["hello"]?.3 = true
        let exp2 = expectation(description: "sync2")
        store.syncAllKeys { (e) in
            XCTAssertNil(e)
            exp2.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertDatabasesAreSynced()
        let (_, _, h, _) = try! store.get("hello")
        XCTAssertEqual(h, true)
        let exp3 = expectation(description: "sync3")
        store.syncAllKeys { (e) in
            XCTAssertNil(e)
            exp3.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertDatabasesAreSynced()
    }
    
    func testRemoteUpdateReplicates() {
        let exp1 = expectation(description: "sync1")
        store.syncAllKeys { (e) in
            XCTAssertNil(e)
            exp1.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertDatabasesAreSynced()
        adapter.db["hello"]?.0 += 1
        adapter.db["hello"]?.1 = Date()
        adapter.db["hello"]?.2 = [0, 1, 1, 1, 1, 1, 11 , 1, 1, 1, 1, 1, 0x8c]
        let exp2 = expectation(description: "sync2")
        store.syncAllKeys { (e) in
            XCTAssertNil(e)
            exp2.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertDatabasesAreSynced()
        let (_, _, _, b) = try! store.get("hello")
        XCTAssertEqual(b, [0, 1, 1, 1, 1, 1, 11 , 1, 1, 1, 1, 1, 0x8c])
        let exp3 = expectation(description: "sync3")
        store.syncAllKeys { (e) in
            XCTAssertNil(e)
            exp3.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertDatabasesAreSynced()
    }
    
    func testEnableEncryptedReplication() {
        adapter.db.removeAll()
        store.encryptedReplication = true
        
        _ = try! store.set("derp", value: [0, 1], localVer: 0)
        let exp = expectation(description: "sync")
        store.syncAllKeys { (err) in
            XCTAssertNil(err)
            exp.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertNotEqual(adapter.db["derp"]!.2, [0, 1])
    }
}
