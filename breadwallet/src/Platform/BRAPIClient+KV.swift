//
//  BRAPIClient+KV.swift
//  breadwallet
//
//  Created by Samuel Sutch on 4/1/17.
//  Copyright © 2017-2019 Breadwinner AG. All rights reserved.
//

import Foundation

private var kvKey: UInt8 = 0

extension BRAPIClient {
    var kv: BRReplicatedKVStore? {
        return Backend.kvStore
    }
}

class KVStoreAdaptor: BRRemoteKVStoreAdaptor {
    let client: BRAPIClient
    
    init(client: BRAPIClient) {
        self.client = client
    }
    
    func ver(key: String, completionFunc: @escaping (UInt64, Date, BRRemoteKVStoreError?) -> Void) {
        var req = URLRequest(url: client.url("/kv/1/\(key)"))
        req.httpMethod = "HEAD"
        client.dataTaskWithRequest(req, authenticated: true, retryCount: 0) { (_, resp, err) in
            if let err = err {
                self.client.log("[KV] HEAD key=\(key) err=\(err)")
                return completionFunc(0, Date(timeIntervalSince1970: 0), .unknown)
            }
            guard let resp = resp, let v = resp.kvVersion, let d = resp.kvDate else {
                return completionFunc(0, Date(timeIntervalSince1970: 0), .unknown)
            }
            completionFunc(v, d, resp.kvError)
        }.resume()
    }
    
    func put(_ key: String, value: [UInt8], version: UInt64, completionFunc: @escaping (UInt64, Date, BRRemoteKVStoreError?) -> Void) {
        var req = URLRequest(url: client.url("/kv/1/\(key)"))
        req.httpMethod = "PUT"
        req.addValue("\(version)", forHTTPHeaderField: "If-None-Match")
        req.addValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        req.addValue("\(value.count)", forHTTPHeaderField: "Content-Length")
        var val = value
        req.httpBody = Data(bytes: &val, count: value.count)
        client.dataTaskWithRequest(req, authenticated: true, retryCount: 0) { (_, resp, err) in
            if let err = err {
                self.client.log("[KV] PUT key=\(key) err=\(err)")
                return completionFunc(0, Date(timeIntervalSince1970: 0), .unknown)
            }
            guard let resp = resp, let v = resp.kvVersion, let d = resp.kvDate else {
                return completionFunc(0, Date(timeIntervalSince1970: 0), .unknown)
            }
            completionFunc(v, d, resp.kvError)
        }.resume()
    }
    
    func del(_ key: String, version: UInt64, completionFunc: @escaping (UInt64, Date, BRRemoteKVStoreError?) -> Void) {
        var req = URLRequest(url: client.url("/kv/1/\(key)"))
        req.httpMethod = "DELETE"
        req.addValue("\(version)", forHTTPHeaderField: "If-None-Match")
        client.dataTaskWithRequest(req, authenticated: true, retryCount: 0) { (_, resp, err) in
            if let err = err {
                self.client.log("[KV] DELETE key=\(key) err=\(err)")
                return completionFunc(0, Date(timeIntervalSince1970: 0), .unknown)
            }
            guard let resp = resp, let v = resp.kvVersion, let d = resp.kvDate else {
                return completionFunc(0, Date(timeIntervalSince1970: 0), .unknown)
            }
            completionFunc(v, d, resp.kvError)
        }.resume()
    }
    
    func get(_ key: String, version: UInt64, completionFunc: @escaping (UInt64, Date, [UInt8], BRRemoteKVStoreError?) -> Void) {
        var req = URLRequest(url: client.url("/kv/1/\(key)"))
        req.httpMethod = "GET"
        req.addValue("\(version)", forHTTPHeaderField: "If-None-Match")
        client.dataTaskWithRequest(req as URLRequest, authenticated: true, retryCount: 0) { (dat, resp, err) in
            if let err = err {
                self.client.log("[KV] GET key=\(key) err=\(err)")
                return completionFunc(0, Date(timeIntervalSince1970: 0), [], .unknown)
            }
            guard let resp = resp, let v = resp.kvVersion,
                let d = resp.kvDate, let dat = dat else {
                    return completionFunc(0, Date(timeIntervalSince1970: 0), [], .unknown)
            }
            let ud = (dat as NSData).bytes.bindMemory(to: UInt8.self, capacity: dat.count)
            let dp = UnsafeBufferPointer<UInt8>(start: ud, count: dat.count)
            completionFunc(v, d, Array(dp), resp.kvError)
        }.resume()
    }
    
    func keys(_ completionFunc: @escaping ([(String, UInt64, Date, BRRemoteKVStoreError?)], BRRemoteKVStoreError?) -> Void) {
        var req = URLRequest(url: client.url("/kv/_all_keys"))
        req.httpMethod = "GET"
        client.dataTaskWithRequest(req as URLRequest, authenticated: true, retryCount: 0) { (dat, resp, err) in
            if let err = err {
                self.client.log("[KV] KEYS err=\(err)")
                return completionFunc([], .unknown)
            }
            guard let resp = resp, let dat = dat, resp.statusCode == 200 else {
                return completionFunc([], .unknown)
            }
            
            // data is encoded as:
            // LE32(num) + (num * (LEU8(keyLeng) + (keyLen * LEU32(char)) + LEU64(ver) + LEU64(msTs) + LEU8(del)))
            var i = UInt(MemoryLayout<UInt32>.size)
            let c = dat.uInt32(atOffset: 0)
            var items = [(String, UInt64, Date, BRRemoteKVStoreError?)]()
            for _ in 0..<c {
                let keyLen = UInt(dat.uInt32(atOffset: i))
                i += UInt(MemoryLayout<UInt32>.size)
                let range: Range<Int> = Int(i)..<Int(i + keyLen)
                guard let key = NSString(data: dat.subdata(in: range),
                                         encoding: String.Encoding.utf8.rawValue) as String? else {
                                            self.client.log("Well crap. Failed to decode a string.")
                                            return completionFunc([], .unknown)
                }
                i += keyLen
                let ver = dat.uInt64(atOffset: i)
                i += UInt(MemoryLayout<UInt64>.size)
                let date = Date.withMsTimestamp(dat.uInt64(atOffset: i))
                i += UInt(MemoryLayout<UInt64>.size)
                let deleted = dat.uInt8(atOffset: i) > 0
                i += UInt(MemoryLayout<UInt8>.size)
                items.append((key, ver, date, deleted ? .tombstone : nil))
                self.client.log("keys: \(key) \(ver) \(date) \(deleted)")
            }
            completionFunc(items, nil)
        }.resume()
    }
}

fileprivate extension HTTPURLResponse {
    var kvDate: Date? {
        if let remDate = self.allHeaderFields["Last-Modified"] as? String, let dateDate = Date.fromRFC1123(remDate) {
            return dateDate
        }
        return nil
    }
    
    var kvVersion: UInt64? {
        if let remVer = self.allHeaderFields["Etag"] as? String, let verInt = UInt64(remVer) {
            return verInt
        }
        return nil
    }
    
    var kvError: BRRemoteKVStoreError? {
        switch self.statusCode {
        case 404:
            return .notFound
        case 409:
            return .conflict
        case 410:
            return .tombstone
        case 200...399:
            return nil
        default:
            return .unknown
        }
    }
}
