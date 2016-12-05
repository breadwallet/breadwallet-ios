//
//  BRKVStorePlugin.swift
//  BreadWallet
//
//  Created by Samuel Sutch on 8/18/16.
//  Copyright © 2016 breawallet LLC. All rights reserved.
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

/// Provides access to the KV Store to the HTML5 platform
@objc class BRKVStorePlugin: NSObject, BRHTTPRouterPlugin {
    let client: BRAPIClient
    
    init(client: BRAPIClient) {
        self.client = client
    }
    
    func transformErrorToResponse(_ request: BRHTTPRequest, err: Error?) -> BRHTTPResponse? {
        switch err {
        case nil:
            return nil
        case let e as BRReplicatedKVStoreError:
            switch e {
            case .notFound:
                return BRHTTPResponse(request: request, code: 404)
            case .conflict:
                return BRHTTPResponse(request: request, code: 409)
            case .invalidKey:
                print("[BRHTTPStorePlugin]: invalid key!")
                return BRHTTPResponse(request: request, code: 400)
            default: break
            }
        default: break
        }
        print("[BRHTTPStorePlugin]: unexpected error: \(err)")
        return BRHTTPResponse(request: request, code: 500)
    }
    
    func getKey(_ s: String) -> String {
        return "plat-\(s)"
    }
    
    func hook(_ router: BRHTTPRouter) {
        // GET /_kv/(key)
        //
        // Retrieve a value from a key. If it exists, the most recent version will be returned as JSON. The ETag header 
        // will be set with the most recent version ID. The Last-Modified header will be set with the most recent
        // version's date
        //
        // If the key was removed the caller will receive a 410 Gone response, with the most recent ETag and 
        // Last-Modified header set appropriately.
        //
        // If you are retrieving a key that was replaced after having deleted it, you may have to instruct your client
        // to ignore its cache (using Pragma: no-cache and Cache-Control: no-cache headers)
        router.get("/_kv/(key)") { (request, match) -> BRHTTPResponse in
            guard let key = match["key"] , key.count == 1 else {
                print("[BRKVStorePlugin] missing key argument")
                return BRHTTPResponse(request: request, code: 400)
            }
            guard let kv = self.client.kv else {
                print("[BRKVStorePlugin] kv store is not yet set up on  client")
                return BRHTTPResponse(request: request, code: 500)
            }
            var ver: UInt64
            var date: Date
            var del: Bool
            var bytes: [UInt8]
            var json: Any
            var uncompressedBytes: [UInt8]
            do {
                (ver, date, del, bytes) = try kv.get(self.getKey(key[0]))
                let data = Data(bzCompressedData: Data(bytes: &bytes, count: bytes.count)) ?? Data()
                json = try JSONSerialization.jsonObject(with: data, options: []) // ensure valid json
                let jsonData = try JSONSerialization.data(withJSONObject: json, options: [])
                uncompressedBytes = [UInt8](repeating: 0, count: jsonData.count)
                (jsonData as NSData).getBytes(&uncompressedBytes, length: jsonData.count)
            } catch let e {
                if let resp = self.transformErrorToResponse(request, err: e) {
                    return resp
                }
                return BRHTTPResponse(request: request, code: 500) // no idea what happened...
            }
            if del {
                let headers: [String: [String]] = [
                    "ETag": ["\(ver)"],
                    "Last-Modified": [date.RFC1123String() ?? ""]
                ]
                return BRHTTPResponse(
                    request: request, statusCode: 410, statusReason: "Gone", headers: headers, body: nil
                )
            }
            let headers: [String: [String]] = [
                "ETag": ["\(ver)"],
                "Last-Modified": [date.RFC1123String() ?? ""],
                "Content-Type": ["application/json"]
            ]
            return BRHTTPResponse(
                request: request, statusCode: 200, statusReason: "OK", headers: headers, body: uncompressedBytes
            )
        }
        
        // PUT /_kv/(key)
        //
        // Save a JSON value under a key. If it's a new key, then pass 0 as the If-None-Match header
        // Otherwise you must pass the current version in the database (which may be retrieved with GET /_kv/(key)
        // If the version in the If-None-Match header doesn't match the one in the database the caller
        // will receive a 409 Conflict response.
        //
        // The request body MUST be encoded as application/json and the encoded body MUST not exceed 500kb
        //
        // Successful response is a 204 no content with the ETag set to the new version and Last-Modified header
        // set to that version's date
        router.put("/_kv/(key)") { (request, match) -> BRHTTPResponse in
            guard let key = match["key"] , key.count == 1 else {
                print("[BRKVStorePlugin] missing key argument")
                return BRHTTPResponse(request: request, code: 400)
            }
            guard let kv = self.client.kv else {
                print("[BRKVStorePlugin] kv store is not yet set up on  client")
                return BRHTTPResponse(request: request, code: 500)
            }
            guard let ct = request.headers["content-type"] , ct.count == 1 && ct[0] == "application/json" else {
                print("[BRKVStorePlugin] can only set application/json request bodies")
                return BRHTTPResponse(request: request, code: 400)
            }
            guard let vs = request.headers["if-none-match"] , vs.count == 1 && Int(vs[0]) != nil else {
                print("[BRKVStorePlugin] missing If-None-Match header, set to `0` if creating a new key")
                return BRHTTPResponse(request: request, code: 400)
            }
            guard let body = request.body(), let compressedBody = body.bzCompressedData else {
                print("[BRKVStorePlugin] missing request body")
                return BRHTTPResponse(request: request, code: 400)
            }
            var bodyBytes = [UInt8](repeating: 0, count: compressedBody.count)
            (compressedBody as NSData).getBytes(&bodyBytes, length: compressedBody.count)
            var ver: UInt64
            var date: Date
            do {
                (ver, date) = try kv.set(self.getKey(key[0]), value: bodyBytes, localVer: UInt64(Int(vs[0])!))
            } catch let e {
                if let resp = self.transformErrorToResponse(request, err: e) {
                    return resp
                }
                return BRHTTPResponse(request: request, code: 500) // no idea what happened...
            }
            let headers: [String: [String]] = [
                "ETag": ["\(ver)"],
                "Last-Modified": [date.RFC1123String() ?? ""]
            ]
            return BRHTTPResponse(
                request: request, statusCode: 204, statusReason: "No Content", headers: headers, body: nil
            )
        }
        
        // DELETE /_kv/(key)
        //
        // Mark a key as deleted in the KV store. The If-None-Match header MUST be the current version stored in the
        // database (which may retrieved with GET /_kv/(key) otherwise the caller will receive a 409 Conflict resposne
        //
        // Keys may not actually be removed from the database, and can be restored by PUTing a new version. This is
        // called a tombstone and is used to replicate deletes to other databases
        router.delete("/_kv/(key)") { (request, match) -> BRHTTPResponse in
            guard let key = match["key"] , key.count == 1 else {
                print("[BRKVStorePlugin] missing key argument")
                return BRHTTPResponse(request: request, code: 400)
            }
            guard let kv = self.client.kv else {
                print("[BRKVStorePlugin] kv store is not yet set up on  client")
                return BRHTTPResponse(request: request, code: 500)
            }
            guard let vs = request.headers["if-none-match"] , vs.count == 1 && Int(vs[0]) != nil else {
                print("[BRKVStorePlugin] missing If-None-Match header")
                return BRHTTPResponse(request: request, code: 400)
            }
            var ver: UInt64
            var date: Date
            do {
                (ver, date) = try kv.del(self.getKey(key[0]), localVer: UInt64(Int(vs[0])!))
            } catch let e {
                if let resp = self.transformErrorToResponse(request, err: e) {
                    return resp
                }
                return BRHTTPResponse(request: request, code: 500) // no idea what happened...
            }
            let headers: [String: [String]] = [
                "ETag": ["\(ver)"],
                "Last-Modified": [date.RFC1123String() ?? ""]
            ]
            return BRHTTPResponse(
                request: request, statusCode: 204, statusReason: "No Content", headers: headers, body: nil
            )
        }
    }
}
