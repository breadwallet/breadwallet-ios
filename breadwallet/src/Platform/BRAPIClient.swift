//
//  BRAPIClient.swift
//  BreadWallet
//
//  Created by Samuel Sutch on 11/4/15.
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

let BRAPIClientErrorDomain = "BRApiClientErrorDomain"

// these flags map to api feature flag name values
// eg "buy-bitcoin-with-cash" is a persistent name in the /me/features list
@objc public enum BRFeatureFlags: Int, CustomStringConvertible {
    case buyBitcoin
    case earlyAccess
    
    public var description: String {
        switch self {
        case .buyBitcoin: return "buy-bitcoin";
        case .earlyAccess: return "early-access";
        }
    }
}

public typealias URLSessionTaskHandler = (Data?, HTTPURLResponse?, NSError?) -> Void
public typealias URLSessionChallengeHandler = (URLSession.AuthChallengeDisposition, URLCredential?) -> Void

// an object which implements BRAPIAdaptor can execute API Requests on the current wallet's behalf
public protocol BRAPIAdaptor {
    // execute an API request against the current wallet
    func dataTaskWithRequest(
        _ request: URLRequest, authenticated: Bool, retryCount: Int,
        handler: @escaping URLSessionTaskHandler
    ) -> URLSessionDataTask
}

extension String {
    static var urlQuoteCharacterSet: CharacterSet {
        let cset = (NSMutableCharacterSet.urlQueryAllowed as NSCharacterSet).mutableCopy() as! NSMutableCharacterSet
        cset.removeCharacters(in: "?=&")
        return cset as CharacterSet
    }
    
    var urlEscapedString: String {
        return self.addingPercentEncoding(
            withAllowedCharacters: String.urlQuoteCharacterSet)!
    }
}

func getHeaderValue(_ k: String, d: [String: String]?) -> String? {
    guard let d = d else {
        return nil
    }
    if let v = d[k] { // short path: attempt to get the header directly
        return v
    }
    let lkKey = k.lowercased() // long path: compare lowercase keys
    for (lk, lv) in d {
        if lk.lowercased() == lkKey {
            return lv
        }
    }
    return nil
}

func getAuthKey() -> BRKey? {
    if let manager = BRWalletManager.sharedInstance(), let authKey = manager.authPrivateKey {
        return BRKey(privateKey: authKey)
    }
    return nil
}

func getDeviceId() -> String {
    let ud = UserDefaults.standard
    if let s = ud.string(forKey: "BR_DEVICE_ID") {
        return s
    }
    let s = CFUUIDCreateString(nil, CFUUIDCreate(nil)) as String
    ud.setValue(s, forKey: "BR_DEVICE_ID")
    print("new device id \(s)")
    return s
}

func isBreadChallenge(_ r: HTTPURLResponse) -> Bool {
    if let headers = r.allHeaderFields as? [String: String],
       let challenge = getHeaderValue("www-authenticate", d: headers) {
        if challenge.lowercased().hasPrefix("bread") {
            return true
        }
    }
    return false
}

func buildURLResourceString(_ url: URL?) -> String {
    var urlStr = ""
    if let url = url {
        urlStr = "\(url.path)"
        if let query = url.query {
            if query.lengthOfBytes(using: String.Encoding.utf8) > 0 {
                urlStr = "\(urlStr)?\(query)"
            }
        }
    }
    return urlStr
}

func buildRequestSigningString(_ r: URLRequest) -> String {
    var parts = [
        r.httpMethod ?? "",
        "",
        getHeaderValue("content-type", d: r.allHTTPHeaderFields) ?? "",
        getHeaderValue("date", d: r.allHTTPHeaderFields) ?? "",
        buildURLResourceString(r.url)
    ]
    if let meth = r.httpMethod {
        switch meth {
        case "POST", "PUT", "PATCH":
            if let d = r.httpBody , d.count > 0 {
                let sha = (d as NSData).sha256()
                parts[1] = (NSData(uInt256: sha) as NSData).base58String()
            }
        default: break
        }
    }
    return parts.joined(separator: "\n")
}


@objc open class BRAPIClient: NSObject, URLSessionDelegate, URLSessionTaskDelegate, BRAPIAdaptor {
    // BRAPIClient is intended to be used as a singleton so this is the instance you should use
    static let sharedClient = BRAPIClient()
    
    // whether or not to emit log messages from this instance of the client
    var logEnabled = true
    
    // proto is the transport protocol to use for talking to the API (either http or https)
    var proto = "https"
    
    // host is the server(s) on which the API is hosted
    var host = "api.breadwallet.com"
    
    // isFetchingAuth is set to true when a request is currently trying to renew authentication (the token)
    // it is useful because fetching auth is not idempotent and not reentrant, so at most one auth attempt
    // can take place at any one time
    fileprivate var isFetchingAuth = false
    
    // used when requests are waiting for authentication to be fetched
    fileprivate var authFetchGroup: DispatchGroup = DispatchGroup()
    
    // storage for the session constructor below
    fileprivate var _session: Foundation.URLSession? = nil
    
    // the NSURLSession on which all NSURLSessionTasks are executed
    fileprivate var session: Foundation.URLSession {
        if _session == nil {
            let config = URLSessionConfiguration.default
            _session = Foundation.URLSession(configuration: config, delegate: self, delegateQueue: queue)
        }
        return _session!
    }
    
    // the queue on which the NSURLSession operates
    fileprivate var queue = OperationQueue()
    
    // convenience getter for the API endpoint
    var baseUrl: String {
        return "\(proto)://\(host)"
    }
    
    // prints whatever you give it if logEnabled is true
    func log(_ s: String) {
        if !logEnabled {
            return
        }
        print("[BRAPIClient] \(s)")
    }
    
    var deviceId: String {
        return getDeviceId()
    }
    
    // MARK: Networking functions
    
    // Constructs a full NSURL for a given path and url parameters
    func url(_ path: String, args: Dictionary<String, String>? =  nil) -> URL {
        func joinPath(_ k: String...) -> URL {
            return URL(string: ([baseUrl] + k).joined(separator: ""))!
        }
        
        if let args = args {
            return joinPath(path + "?" + args.map({
                "\($0.0.urlEscapedString)=\($0.1.urlEscapedString)"
            }).joined(separator: "&"))
        } else {
            return joinPath(path)
        }
    }
    
    func signRequest(_ request: URLRequest) -> URLRequest {
        var mutableRequest = request
        let dateHeader = getHeaderValue("date", d: mutableRequest.allHTTPHeaderFields)
        if dateHeader == nil {
            // add Date header if necessary
            mutableRequest.setValue(Date().RFC1123String(), forHTTPHeaderField: "Date")
        }
        if let manager = BRWalletManager.sharedInstance(),
            let tokenData = manager.userAccount,
            let token = tokenData["token"],
            let authKey = getAuthKey(),
            let signingData = buildRequestSigningString(mutableRequest).data(using: String.Encoding.utf8),
            let sig = authKey.compactSign((signingData as NSData).sha256_2()) {
            let hval = "bread \(token):\((sig as NSData).base58String())"
            mutableRequest.setValue(hval, forHTTPHeaderField: "Authorization")
        }
        return mutableRequest as URLRequest
    }
    
    open func dataTaskWithRequest(_ request: URLRequest, authenticated: Bool = false,
                             retryCount: Int = 0, handler: @escaping URLSessionTaskHandler) -> URLSessionDataTask {
        let start = Date()
        var logLine = ""
        if let meth = request.httpMethod, let u = request.url {
            logLine = "\(meth) \(u) auth=\(authenticated) retry=\(retryCount)"
        }
        let origRequest = (request as NSURLRequest).mutableCopy() as! URLRequest
        var actualRequest = request
        if authenticated {
            actualRequest = signRequest(request)
        }
        return session.dataTask(with: actualRequest, completionHandler: { (data, resp, err) -> Void in
            DispatchQueue.main.async {
                let end = Date()
                let dur = Int(end.timeIntervalSince(start) * 1000)
                if let httpResp = resp as? HTTPURLResponse {
                    var errStr = ""
                    if httpResp.statusCode >= 400 {
                        if let data = data, let s = NSString(data: data, encoding: String.Encoding.utf8.rawValue) {
                            errStr = s as String
                        }
                    }
                    
                    self.log("\(logLine) -> status=\(httpResp.statusCode) duration=\(dur)ms errStr=\(errStr)")
                    
                    if authenticated && isBreadChallenge(httpResp) {
                        self.log("\(logLine) got authentication challenge from API - will attempt to get token")
                        self.getToken { err in
                            if err != nil && retryCount < 1 { // retry once
                                self.log("\(logLine) error retrieving token: \(err) - will retry")
                                DispatchQueue.main.asyncAfter(deadline: DispatchTime(uptimeNanoseconds: 1)) {
                                    self.dataTaskWithRequest(
                                        origRequest, authenticated: authenticated,
                                        retryCount: retryCount + 1, handler: handler
                                    ).resume()
                                }
                            } else if err != nil && retryCount > 0 { // fail if we already retried
                                self.log("\(logLine) error retrieving token: \(err) - will no longer retry")
                                handler(nil, nil, err)
                            } else if retryCount < 1 { // no error, so attempt the request again
                                self.log("\(logLine) retrieved token, so retrying the original request")
                                self.dataTaskWithRequest(
                                    origRequest, authenticated: authenticated,
                                    retryCount: retryCount + 1, handler: handler).resume()
                            } else {
                                self.log("\(logLine) retried token multiple times, will not retry again")
                                handler(data, httpResp, err)
                            }
                        }
                    } else {
                        handler(data, httpResp, err as NSError?)
                    }
                } else {
                    self.log("\(logLine) encountered connection error \(err)")
                    handler(data, nil, err as NSError?)
                }
            }
        }) 
    }
    
    // retrieve a token and save it in the keychain data for this account
    func getToken(_ handler: @escaping (NSError?) -> Void) {
        if isFetchingAuth {
            log("already fetching auth, waiting...")
            authFetchGroup.notify(queue: DispatchQueue.main) {
                handler(nil)
            }
            return
        }
        guard let authKey = getAuthKey(), let authPubKey = authKey.publicKey else {
            return handler(NSError(domain: BRAPIClientErrorDomain, code: 500, userInfo: [
                NSLocalizedDescriptionKey: NSLocalizedString("Wallet not ready", comment: "")]))
        }
        isFetchingAuth = true
        log("auth: entering group")
        authFetchGroup.enter()
        var req = URLRequest(url: url("/token"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let reqJson = [
            "pubKey": (authPubKey as NSData).base58String(),
            "deviceID": getDeviceId()
        ]
        do {
            let dat = try JSONSerialization.data(withJSONObject: reqJson, options: [])
            req.httpBody = dat
        } catch let e {
            log("JSON Serialization error \(e)")
            isFetchingAuth = false
            authFetchGroup.leave()
            return handler(NSError(domain: BRAPIClientErrorDomain, code: 500, userInfo: [
                NSLocalizedDescriptionKey: NSLocalizedString("JSON Serialization Error", comment: "")]))
        }
        session.dataTask(with: req, completionHandler: { (data, resp, err) in
            DispatchQueue.main.async {
                if let httpResp = resp as? HTTPURLResponse {
                    // unsuccessful response from the server
                    if httpResp.statusCode != 200 {
                        if let data = data, let s = String(data: data, encoding: String.Encoding.utf8) {
                            self.log("Token error: \(s)")
                        }
                        self.isFetchingAuth = false
                        self.authFetchGroup.leave()
                        return handler(NSError(domain: BRAPIClientErrorDomain, code: httpResp.statusCode, userInfo: [
                            NSLocalizedDescriptionKey: NSLocalizedString("Unable to retrieve API token", comment: "")]))
                    }
                }
                if let data = data {
                    do {
                        let json = try JSONSerialization.jsonObject(with: data, options: .allowFragments)
                        self.log("POST /token json response: \(json)")
                        if let topObj = json as? NSDictionary,
                            let tok = topObj["token"] as? NSString,
                            let uid = topObj["userID"] as? NSString,
                            let walletManager = BRWalletManager.sharedInstance() {
                            // success! store it in the keychain
                            let kcData = ["token": tok, "userID": uid]
                            walletManager.userAccount = kcData
                        }
                    } catch let e {
                        self.log("JSON Deserialization error \(e)")
                    }
                }
                self.isFetchingAuth = false
                self.authFetchGroup.leave()
                handler(err as NSError?)
            }
        }) .resume()
    }
    
    // MARK: URLSession Delegate

    public func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            if (challenge.protectionSpace.host == host && challenge.protectionSpace.serverTrust != nil) {
                log("URLSession challenge accepted!")
                completionHandler(.useCredential,
                    URLCredential(trust: challenge.protectionSpace.serverTrust!))
            } else {
                log("URLSession challenge rejected")
                completionHandler(.rejectProtectionSpace, nil)
            }
        }
    }
    
    // MARK: API Functions
    
    // Fetches the /v1/fee-per-kb endpoint
    open func feePerKb(_ handler: @escaping (_ feePerKb: uint_fast64_t, _ error: String?) -> Void) {
        let req = URLRequest(url: url("/fee-per-kb"))
        let task = self.dataTaskWithRequest(req) { (data, response, err) -> Void in
            var feePerKb: uint_fast64_t = 0
            var errStr: String? = nil
            if err == nil {
                do {
                    let parsedObject: Any? = try JSONSerialization.jsonObject(
                        with: data!, options: JSONSerialization.ReadingOptions.allowFragments)
                    if let top = parsedObject as? NSDictionary, let n = top["fee_per_kb"] as? NSNumber {
                        feePerKb = n.uint64Value
                    }
                } catch (let e) {
                    self.log("fee-per-kb: error parsing json \(e)")
                }
                if feePerKb == 0 {
                    errStr = "invalid json"
                }
            } else {
                self.log("fee-per-kb network error: \(err)")
                errStr = "bad network connection"
            }
            handler(feePerKb, errStr)
        }
        task.resume()
    }
    
    // MARK: push notifications
    
    open func savePushNotificationToken(_ token: Data, pushNotificationType: String = "d") {
        var req = URLRequest(url: url("/me/push-devices"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let reqJson = [
            "token": token.hexString,
            "service": "apns",
            "data": ["e": pushNotificationType]
        ] as [String : Any]
        do {
            let dat = try JSONSerialization.data(withJSONObject: reqJson, options: .prettyPrinted)
            req.httpBody = dat
        } catch (let e) {
            log("JSON Serialization error \(e)")
            return //handler(NSError(domain: BRAPIClientErrorDomain, code: 500, userInfo: [
                //NSLocalizedDescriptionKey: NSLocalizedString("JSON Serialization Error", comment: "")]))
        }
        dataTaskWithRequest(req as URLRequest, authenticated: true, retryCount: 0) { (dat, resp, er) in
            let dat2 = NSString(data: (dat != nil ? dat! : Data()), encoding: String.Encoding.utf8.rawValue)
            self.log("token resp: \(resp) data: \(dat2)")
        }.resume()
    }
    
    // MARK: feature flags API
    
    open func defaultsKeyForFeatureFlag(_ name: String) -> String {
        return "ff:\(name)"
    }
    
    open func updateFeatureFlags() {
        var authenticated = false
        var furl = "/anybody/features"
        // only use authentication if the user has previously used authenticated services
        if let wm = BRWalletManager.sharedInstance(), let _ = wm.userAccount {
            authenticated = true
            furl = "/me/features"
        }
        let req = URLRequest(url: url(furl))
        dataTaskWithRequest(req, authenticated: authenticated) { (data, resp, err) in
            if let resp = resp, let data = data {
                if resp.statusCode == 200 {
                    let defaults = UserDefaults.standard
                    do {
                        let j = try JSONSerialization.jsonObject(with: data, options: [])
                        let features = j as! [[String: AnyObject]]
                        for feat in features {
                            if let fn = feat["name"], let fname = fn as? String,
                                let fe = feat["enabled"], let fenabled = fe as? Bool {
                                self.log("feature \(fname) enabled: \(fenabled)")
                                defaults.set(fenabled, forKey: self.defaultsKeyForFeatureFlag(fname))
                            } else {
                                self.log("malformed feature: \(feat)")
                            }
                        }
                    } catch let e {
                        self.log("error loading features json: \(e)")
                    }
                }
            } else {
                self.log("error fetching features: \(err)")
            }
        }.resume()
    }
    
    open func featureEnabled(_ flag: BRFeatureFlags) -> Bool {
        let defaults = UserDefaults.standard
        return defaults.bool(forKey: defaultsKeyForFeatureFlag(flag.description))
    }
    
    // MARK: key value access
    
    fileprivate class KVStoreAdaptor: BRRemoteKVStoreAdaptor {
        let client: BRAPIClient
        
        init(client: BRAPIClient) {
            self.client = client
        }
        
        func ver(key: String, completionFunc: @escaping (UInt64, Date, BRRemoteKVStoreError?) -> ()) {
            var req = URLRequest(url: client.url("/kv/1/\(key)"))
            req.httpMethod = "HEAD"
            client.dataTaskWithRequest(req, authenticated: true, retryCount: 0) { (dat, resp, err) in
                if let err = err {
                    self.client.log("[KV] HEAD key=\(key) err=\(err)")
                    return completionFunc(0, Date(timeIntervalSince1970: 0), .unknown)
                }
                guard let resp = resp, let v = self._extractVersion(resp), let d = self._extractDate(resp) else {
                    return completionFunc(0, Date(timeIntervalSince1970: 0), .unknown)
                }
                completionFunc(v, d, self._extractErr(resp))
            }.resume()
        }
        
        func put(_ key: String, value: [UInt8], version: UInt64,
                 completionFunc: @escaping (UInt64, Date, BRRemoteKVStoreError?) -> ()) {
            var req = URLRequest(url: client.url("/kv/1/\(key)"))
            req.httpMethod = "PUT"
            req.addValue("\(version)", forHTTPHeaderField: "If-None-Match")
            req.addValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
            req.addValue("\(value.count)", forHTTPHeaderField: "Content-Length")
            var val = value
            req.httpBody = Data(bytes: &val, count: value.count)
            client.dataTaskWithRequest(req, authenticated: true, retryCount: 0) { (dat, resp, err) in
                if let err = err {
                    self.client.log("[KV] PUT key=\(key) err=\(err)")
                    return completionFunc(0, Date(timeIntervalSince1970: 0), .unknown)
                }
                guard let resp = resp, let v = self._extractVersion(resp), let d = self._extractDate(resp) else {
                    return completionFunc(0, Date(timeIntervalSince1970: 0), .unknown)
                }
                completionFunc(v, d, self._extractErr(resp))
            }.resume()
        }
        
        func del(_ key: String, version: UInt64,
                 completionFunc: @escaping (UInt64, Date, BRRemoteKVStoreError?) -> ()) {
            var req = URLRequest(url: client.url("/kv/1/\(key)"))
            req.httpMethod = "DELETE"
            req.addValue("\(version)", forHTTPHeaderField: "If-None-Match")
            client.dataTaskWithRequest(req, authenticated: true, retryCount: 0) { (dat, resp, err) in
                if let err = err {
                    self.client.log("[KV] DELETE key=\(key) err=\(err)")
                    return completionFunc(0, Date(timeIntervalSince1970: 0), .unknown)
                }
                guard let resp = resp, let v = self._extractVersion(resp), let d = self._extractDate(resp) else {
                    return completionFunc(0, Date(timeIntervalSince1970: 0), .unknown)
                }
                completionFunc(v, d, self._extractErr(resp))
            }.resume()
        }
        
        func get(_ key: String, version: UInt64,
                 completionFunc: @escaping (UInt64, Date, [UInt8], BRRemoteKVStoreError?) -> ()) {
            var req = URLRequest(url: client.url("/kv/1/\(key)"))
            req.httpMethod = "GET"
            req.addValue("\(version)", forHTTPHeaderField: "If-None-Match")
            client.dataTaskWithRequest(req as URLRequest, authenticated: true, retryCount: 0) { (dat, resp, err) in
                if let err = err {
                    self.client.log("[KV] GET key=\(key) err=\(err)")
                    return completionFunc(0, Date(timeIntervalSince1970: 0), [], .unknown)
                }
                guard let resp = resp, let v = self._extractVersion(resp),
                    let d = self._extractDate(resp), let dat = dat else {
                    return completionFunc(0, Date(timeIntervalSince1970: 0), [], .unknown)
                }
                let ud = (dat as NSData).bytes.bindMemory(to: UInt8.self, capacity: dat.count)
                let dp = UnsafeBufferPointer<UInt8>(start: ud, count: dat.count)
                completionFunc(v, d, Array(dp), self._extractErr(resp))
            }.resume()
        }
        
        func keys(_ completionFunc:
                  @escaping ([(String, UInt64, Date, BRRemoteKVStoreError?)], BRRemoteKVStoreError?) -> ()) {
            var req = URLRequest(url: client.url("/kv/_all_keys"))
            req.httpMethod = "GET"
            client.dataTaskWithRequest(req as URLRequest, authenticated: true, retryCount: 0) { (dat, resp, err) in
                if let err = err {
                    self.client.log("[KV] KEYS err=\(err)")
                    return completionFunc([], .unknown)
                }
                guard let resp = resp, let dat = dat , resp.statusCode == 200 else {
                    return completionFunc([], .unknown)
                }
                
                // data is encoded as:
                // LE32(num) + (num * (LEU8(keyLeng) + (keyLen * LEU32(char)) + LEU64(ver) + LEU64(msTs) + LEU8(del)))
                var i = UInt(MemoryLayout<UInt32>.size)
                let c = (dat as NSData).uInt32(atOffset: 0)
                var items = [(String, UInt64, Date, BRRemoteKVStoreError?)]()
                for _ in 0..<c {
                    let keyLen = UInt((dat as NSData).uInt32(atOffset: i))
                    i += UInt(MemoryLayout<UInt32>.size)
                    let range: Range<Int> = Int(i)..<Int(i + keyLen)
                    guard let key = NSString(data: dat.subdata(in: range),
                                             encoding: String.Encoding.utf8.rawValue) as? String else {
                        self.client.log("Well crap. Failed to decode a string.")
                        return completionFunc([], .unknown)
                    }
                    i += keyLen
                    let ver = (dat as NSData).uInt64(atOffset: i)
                    i += UInt(MemoryLayout<UInt64>.size)
                    let date = Date.withMsTimestamp((dat as NSData).uInt64(atOffset: i))
                    i += UInt(MemoryLayout<UInt64>.size)
                    let deleted = (dat as NSData).uInt8(atOffset: i) > 0
                    i += UInt(MemoryLayout<UInt8>.size)
                    items.append((key, ver, date, deleted ? .tombstone : nil))
                    self.client.log("keys: \(key) \(ver) \(date) \(deleted)")
                }
                completionFunc(items, nil)
            }.resume()
        }
        
        func _extractDate(_ r: HTTPURLResponse) -> Date? {
            if let remDate = r.allHeaderFields["Last-Modified"] as? String, let dateDate = Date.fromRFC1123(remDate) {
                return dateDate
            }
            return nil
        }
        
        func _extractVersion(_ r: HTTPURLResponse) -> UInt64? {
            if let remVer = r.allHeaderFields["Etag"] as? String, let verInt = UInt64(remVer) {
                return verInt
            }
            return nil
        }
        
        func _extractErr(_ r: HTTPURLResponse) -> BRRemoteKVStoreError? {
            switch r.statusCode {
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
    
    fileprivate var _kvStore: BRReplicatedKVStore? = nil
    
    open var kv: BRReplicatedKVStore? {
        get {
            if let k = _kvStore {
                return k
            }
            if let key = getAuthKey() {
                _kvStore = try? BRReplicatedKVStore(encryptionKey: key, remoteAdaptor: KVStoreAdaptor(client: self))
                return _kvStore
            }
            return nil
        }
    }
    
    // MARK: Assets API
    
    open class func bundleURL(_ bundleName: String) -> URL {
        let fm = FileManager.default
        let docsUrl = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let bundleDirUrl = docsUrl.appendingPathComponent("bundles", isDirectory: true)
        let bundleUrl = bundleDirUrl.appendingPathComponent("\(bundleName)-extracted", isDirectory: true)
        return bundleUrl
    }
    
    open func updateBundle(_ bundleName: String, handler: @escaping (_ error: String?) -> Void) {
        // 1. check if we already have a bundle given the name
        // 2. if we already have it:
        //    2a. get the sha256 of the on-disk bundle
        //    2b. request the versions of the bundle from server
        //    2c. request the diff between what we have and the newest one, if ours is not already the newest
        //    2d. apply the diff and extract to the bundle folder
        // 3. otherwise:
        //    3a. download and extract the bundle
        
        // set up the environment
        let fm = FileManager.default
        let docsUrl = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let bundleDirUrl = docsUrl.appendingPathComponent("bundles", isDirectory: true)
        let bundleUrl = bundleDirUrl.appendingPathComponent("\(bundleName).tar")
        let bundleDirPath = bundleDirUrl.path
        let bundlePath = bundleUrl.path
        let bundleExtractedUrl = bundleDirUrl.appendingPathComponent("\(bundleName)-extracted")
        let bundleExtractedPath = bundleExtractedUrl.path
        print("[BRAPIClient] bundleUrl \(bundlePath)")
        
        // determines if the bundle exists, but also creates the bundles/extracted directory if it doesn't exist
        func exists() throws -> Bool {
            var attrs = try? fm.attributesOfItem(atPath: bundleDirPath)
            if attrs == nil {
                try fm.createDirectory(atPath: bundleDirPath, withIntermediateDirectories: true, attributes: nil)
                attrs = try fm.attributesOfItem(atPath: bundleDirPath)
            }
            var attrsExt = try? fm.attributesOfFileSystem(forPath: bundleExtractedPath)
            if attrsExt == nil {
                try fm.createDirectory(atPath: bundleExtractedPath, withIntermediateDirectories: true, attributes: nil)
                attrsExt = try fm.attributesOfItem(atPath: bundleExtractedPath)
            }
            return fm.fileExists(atPath: bundlePath)
        }
        
        // extracts the bundle
        func extract() throws {
            try BRTar.createFilesAndDirectoriesAtPath(bundleExtractedPath, withTarPath: bundlePath)
        }
        
        guard var bundleExists = try? exists() else {
            return handler(NSLocalizedString("error determining if bundle exists", comment: "")) }
        
        // attempt to use the tar file that was bundled with the binary
        if !bundleExists {
            if let bundledBundleUrl = Bundle.main.url(forResource: bundleName, withExtension: "tar") {
                do {
                    try fm.copyItem(at: bundledBundleUrl, to: bundleUrl)
                    bundleExists = true
                    log("used bundled bundle for \(bundleName)")
                } catch let e {
                    log("unable to copy bundled bundle `\(bundleName)` \(bundledBundleUrl) -> \(bundleUrl): \(e)")
                }
            }
        }
        
        if bundleExists {
            // bundle exists, download and apply the diff, then remove diff file
            log("bundle \(bundleName) exists, fetching diff for most recent version")
            
            guard let curBundleContents = try? Data(contentsOf: URL(fileURLWithPath: bundlePath)) else {
                return handler(NSLocalizedString("error reading current bundle", comment: "")) }
            
            let curBundleSha = (NSData(uInt256: (curBundleContents as NSData).sha256()) as Data).hexString
            
            dataTaskWithRequest(URLRequest(url: url("/assets/bundles/\(bundleName)/versions")))
                { (data, resp, err) -> Void in
                    if let data = data,
                        let parsed = try? JSONSerialization.jsonObject(with: data, options: .allowFragments),
                        let top = parsed as? NSDictionary,
                        let versions = top["versions"] as? [String]
                        , err == nil {
                            if versions.index(of: curBundleSha) == (versions.count - 1) {
                                // have the most recent version
                                self.log("already at most recent version of bundle \(bundleName)")
                                do {
                                    try extract()
                                    return handler(nil)
                                } catch let e {
                                    return handler(NSLocalizedString("error extracting bundle: " + "\(e)", comment: ""))
                                }
                            } else { // don't have the most recent version, download diff
                                self.log("Fetching most recent version of bundle \(bundleName)")
                                let req = URLRequest(url:
                                    self.url("/assets/bundles/\(bundleName)/diff/\(curBundleSha)"))
                                self.dataTaskWithRequest(req, handler: { (diffDat, diffResp, diffErr) -> Void in
                                    if let diffDat = diffDat , diffErr == nil {
                                        let diffPath = bundleDirUrl.appendingPathComponent("\(bundleName).diff").path
                                        let oldBundlePath = bundleDirUrl.appendingPathComponent("\(bundleName).old").path
                                        do {
                                            if fm.fileExists(atPath: diffPath) {
                                                try fm.removeItem(atPath: diffPath)
                                            }
                                            if fm.fileExists(atPath: oldBundlePath) {
                                                try fm.removeItem(atPath: oldBundlePath)
                                            }
                                            try diffDat.write(to: URL(fileURLWithPath: diffPath), options: .atomic)
                                            try fm.moveItem(atPath: bundlePath, toPath: oldBundlePath)
                                            _ = try BRBSPatch.patch(
                                                oldBundlePath, newFilePath: bundlePath, patchFilePath: diffPath)
                                            try fm.removeItem(atPath: diffPath)
                                            try fm.removeItem(atPath: oldBundlePath)
                                            try extract()
                                            return handler(nil)
                                        } catch let e {
                                            // something failed, clean up whatever we can, next attempt 
                                            // will download fresh
                                            _ = try? fm.removeItem(atPath: diffPath)
                                            _ = try? fm.removeItem(atPath: oldBundlePath)
                                            _ = try? fm.removeItem(atPath: bundlePath)
                                            return handler(
                                                NSLocalizedString("error downloading diff: " + "\(e)", comment: ""))
                                        }
                                    }
                                }).resume()
                            }
                        }
                    else {
                        return handler(NSLocalizedString("error determining versions", comment: ""))
                    }
                }.resume()
        } else {
            // bundle doesn't exist. download a fresh copy
            log("bundle \(bundleName) doesn't exist, downloading new copy")
            let req = URLRequest(url: url("/assets/bundles/\(bundleName)/download"))
            dataTaskWithRequest(req) { (data, response, err) -> Void in
                if err != nil || response?.statusCode != 200 {
                    return handler(NSLocalizedString("error fetching bundle: ", comment: "") + "\(err)")
                }
                if let data = data {
                    do {
                        try data.write(to: URL(fileURLWithPath: bundlePath), options: .atomic)
                        try extract()
                        return handler(nil)
                    } catch let e {
                        return handler(NSLocalizedString("error writing bundle file: ", comment: "") + "\(e)")
                    }
                }
            }.resume()
        }
    }
}

