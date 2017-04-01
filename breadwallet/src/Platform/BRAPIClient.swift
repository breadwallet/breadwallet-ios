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
import BRCore

let BRAPIClientErrorDomain = "BRApiClientErrorDomain"

// these flags map to api feature flag name values
// eg "buy-bitcoin-with-cash" is a persistent name in the /me/features list
@objc public enum BRFeatureFlags : Int, CustomStringConvertible {
    case buyBitcoin
    case earlyAccess
    
    public var description: String {
        switch self {
        case .buyBitcoin: return "buy-bitcoin";
        case .earlyAccess: return "early-access";
        }
    }
}

public enum BRAPIClientError: Error {
    case malformedDataError
    case unknownError
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
                parts[1] = d.sha256.base58
            }
        default: break
        }
    }
    return parts.joined(separator: "\n")
}


open class BRAPIClient : NSObject, URLSessionDelegate, URLSessionTaskDelegate, BRAPIAdaptor {
    var authenticator: WalletAuthenticator
    
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
    fileprivate var authFetchGroup = DispatchGroup()

    // the NSURLSession on which all NSURLSessionTasks are executed
    lazy fileprivate var session: URLSession = URLSession(configuration: .default, delegate: self, delegateQueue: self.queue)

    // the queue on which the NSURLSession operates
    fileprivate var queue = OperationQueue()
    
    // convenience getter for the API endpoint
    var baseUrl: String {
        return "\(proto)://\(host)"
    }
    
    init(authenticator: WalletAuthenticator) {
        self.authenticator = authenticator
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
    
    var authKey: BRKey? {
        if authenticator.noWallet { return nil }
        guard let keyStr = authenticator.apiAuthKey else { return nil }
        var key = BRKey()
        key.compressed = 1 
        if BRKeySetPrivKey(&key, keyStr) == 0 {
            #if DEBUG
                fatalError("Unable to decode private key")
            #endif
        }
        return key
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
        if let tokenData = authenticator.userAccount,
            let token = tokenData["token"] as? String,
            let authKey = authKey,
            let signingData = buildRequestSigningString(mutableRequest).data(using: .utf8) {
            let sig = signingData.sha256_2.compactSign(key: authKey)
            let hval = "bread \(token):\(sig.base58)"
            mutableRequest.setValue(hval, forHTTPHeaderField: "Authorization")
        }
        return mutableRequest
    }
    
    open func dataTaskWithRequest(_ request: URLRequest, authenticated: Bool = false,
                             retryCount: Int = 0, handler: @escaping URLSessionTaskHandler) -> URLSessionDataTask {
        let start = Date()
        var logLine = ""
        if let meth = request.httpMethod, let u = request.url {
            logLine = "\(meth) \(u) auth=\(authenticated) retry=\(retryCount)"
        }
        
        // copy the request and authenticate it. retain the original request for retries
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
                        if let data = data, let s = String(data: data, encoding: .utf8) {
                            errStr = s
                        }
                    }
                    
                    self.log("\(logLine) -> status=\(httpResp.statusCode) duration=\(dur)ms errStr=\(errStr)")
                    
                    if authenticated && isBreadChallenge(httpResp) {
                        self.log("\(logLine) got authentication challenge from API - will attempt to get token")
                        self.getToken { err in
                            if err != nil && retryCount < 1 { // retry once
                                self.log("\(logLine) error retrieving token: \(String(describing: err)) - will retry")
                                DispatchQueue.main.asyncAfter(deadline: DispatchTime(uptimeNanoseconds: 1)) {
                                    self.dataTaskWithRequest(
                                        request, authenticated: authenticated,
                                        retryCount: retryCount + 1, handler: handler
                                    ).resume()
                                }
                            } else if err != nil && retryCount > 0 { // fail if we already retried
                                self.log("\(logLine) error retrieving token: \(String(describing: err)) - will no longer retry")
                                handler(nil, nil, err)
                            } else if retryCount < 1 { // no error, so attempt the request again
                                self.log("\(logLine) retrieved token, so retrying the original request")
                                self.dataTaskWithRequest(
                                    request, authenticated: authenticated,
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
                    self.log("\(logLine) encountered connection error \(String(describing: err))")
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
        guard let authKey = authKey else {
            return handler(NSError(domain: BRAPIClientErrorDomain, code: 500, userInfo: [
                NSLocalizedDescriptionKey: NSLocalizedString("Wallet not ready", comment: "")]))
        }
        let authPubKey = authKey.publicKey
        isFetchingAuth = true
        log("auth: entering group")
        authFetchGroup.enter()
        var req = URLRequest(url: url("/token"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let reqJson = [
            "pubKey": authPubKey.base58,
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
                        if let data = data, let s = String(data: data, encoding: .utf8) {
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
                        if let topObj = json as? [String: Any],
                            let tok = topObj["token"] as? String,
                            let uid = topObj["userID"] as? String {
                            // success! store it in the keychain
                            var kcData = self.authenticator.userAccount ?? [AnyHashable: Any]()
                            kcData["token"] = tok
                            kcData["userID"] = uid
                            self.authenticator.userAccount = kcData
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
                self.log("fee-per-kb network error: \(String(describing: err))")
                errStr = "bad network connection"
            }
            handler(feePerKb, errStr)
        }
        task.resume()
    }

    func exchangeRates(_ handler: @escaping (_ rates: [Rate], _ error: String?) -> Void) {
        let request = URLRequest(url: url("/rates"))
        let task = dataTaskWithRequest(request) { (data, response, error) in
            guard error == nil else { return handler([], error!.localizedDescription) }
            guard let data = data else { return handler([], "/rates returned no data") }
            guard let parsedData = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) else { return handler([], "/rates bad data format") }
            guard let dict = parsedData as? [String: Any] else { return handler([], "/rates didn't return a dictionary") }
            guard let array = dict["body"] as? [Any] else { return handler([], "/rates didn't return an array for body key") }
            handler(array.flatMap { Rate(data: $0) }, nil)
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
            return
        }
        dataTaskWithRequest(req as URLRequest, authenticated: true, retryCount: 0) { (dat, resp, er) in
            let dat2 = String(data: dat ?? Data(), encoding: .utf8)
            self.log("save push token resp: \(String(describing: resp)) data: \(String(describing: dat2))")
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
        if let _ = authenticator.userAccount?["token"] {
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
                self.log("error fetching features: \(String(describing: err))")
            }
        }.resume()
    }
    
    open func featureEnabled(_ flag: BRFeatureFlags) -> Bool {
        let defaults = UserDefaults.standard
        return defaults.bool(forKey: defaultsKeyForFeatureFlag(flag.description))
    }
}

