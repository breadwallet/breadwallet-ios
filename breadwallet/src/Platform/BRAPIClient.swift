//
//  BRAPIClient.swift
//  BreadWallet
//
//  Created by Samuel Sutch on 11/4/15.
//  Copyright (c) 2016-2019 Breadwinner AG. All rights reserved.
//

import Foundation
import BRCrypto

let BRAPIClientErrorDomain = "BRApiClientErrorDomain"

public enum BRAPIClientError: Error {
    case malformedDataError
    case unknownError
}

public typealias URLSessionTaskHandler = (Data?, HTTPURLResponse?, NSError?) -> Void
public typealias URLSessionChallengeHandler = (URLSession.AuthChallengeDisposition, URLCredential?) -> Void

// an object which implements BRAPIAdaptor can execute API Requests on the current wallet's behalf
public protocol BRAPIAdaptor {
    // execute an API request against the current wallet
    func dataTaskWithRequest(_ request: URLRequest,
                             authenticated: Bool,
                             retryCount: Int,
                             responseQueue: DispatchQueue,
                             handler: @escaping URLSessionTaskHandler) -> URLSessionDataTask
    
    func url(_ path: String, args: [String: String]?) -> URL
}

open class BRAPIClient: NSObject, URLSessionDelegate, URLSessionTaskDelegate, BRAPIAdaptor {
    private var authenticator: WalletAuthenticator
    
    // whether or not to emit log messages from this instance of the client
    private var logEnabled = true
    
    // proto is the transport protocol to use for talking to the API (either http or https)
    var proto = "https"
    
    // host is the server(s) on which the API is hosted
    var host = C.backendHost
    
    // isFetchingAuth is set to true when a request is currently trying to renew authentication (the token)
    // it is useful because fetching auth is not idempotent and not reentrant, so at most one auth attempt
    // can take place at any one time
    private var isFetchingAuth = false
    
    // used when requests are waiting for authentication to be fetched
    private var authFetchGroup = DispatchGroup()

    // the NSURLSession on which all NSURLSessionTasks are executed
    lazy private(set) var session: URLSession = URLSession(configuration: .default, delegate: self, delegateQueue: self.queue)

    // the queue on which the NSURLSession operates
    private var queue = OperationQueue()
    
    // convenience getter for the API endpoint
    var baseUrl: String {
        return "\(proto)://\(host)"
    }
    
    init(authenticator: WalletAuthenticator) {
        self.authenticator = authenticator
        super.init()
        if !self.authenticator.noWallet {
            getToken { _ in } // pre-fetch token
        }
    }
    
    // prints whatever you give it if logEnabled is true
    func log(_ s: String) {
        if !logEnabled {
            return
        }
        print("[BRAPIClient] \(s)")
    }
    
    var deviceId: String {
        return UserDefaults.deviceID
    }
    
    var authKey: Key? {
        if authenticator.noWallet { return nil }
        let key = authenticator.apiAuthKey
        assert(key != nil)
        return key
    }
    
    // MARK: Networking functions
    
    // Constructs a full NSURL for a given path and url parameters
    public func url(_ path: String, args: [String: String]? =  nil) -> URL {
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

    private func signRequest(_ request: URLRequest) -> URLRequest {
        var mutableRequest = request
        let dateHeader = mutableRequest.allHTTPHeaderFields?.get(lowercasedKey: "date")
        if dateHeader == nil {
            // add Date header if necessary
            mutableRequest.setValue(Date().RFC1123String(), forHTTPHeaderField: "Date")
        }
        if let tokenData = authenticator.apiUserAccount,
            let token = tokenData["token"] as? String,
            let authKey = authKey,
            let signingData = mutableRequest.signingString.data(using: .utf8),
            let sig = signingData.sha256_2.compactSign(key: authKey) {
            let hval = "bread \(token):\(sig.base58)"
            mutableRequest.setValue(hval, forHTTPHeaderField: "Authorization")
        }
        return mutableRequest
    }
    
    private func decorateRequest(_ request: URLRequest) -> URLRequest {
        var actualRequest = request
        actualRequest.setValue("\(E.isTestnet ? 1 : 0)", forHTTPHeaderField: "X-Bitcoin-Testnet")
        actualRequest.setValue("\((E.isTestFlight || E.isDebug) ? 1 : 0)", forHTTPHeaderField: "X-Testflight")
        actualRequest.setValue(Locale.current.identifier, forHTTPHeaderField: "Accept-Language")
        actualRequest.setValue(BRUserAgentHeaderGenerator.userAgentHeader, forHTTPHeaderField: "User-Agent")
        if let walletID = Store.state.walletID {
            actualRequest.setValue(walletID, forHTTPHeaderField: "X-Wallet-Id")
        }
        return actualRequest
    }
        
    public func dataTaskWithRequest(_ request: URLRequest,
                                    authenticated: Bool = false,
                                    retryCount: Int = 0,
                                    responseQueue: DispatchQueue = DispatchQueue.main,
                                    handler: @escaping URLSessionTaskHandler) -> URLSessionDataTask {
        let start = Date()
        var logLine = ""
        if let meth = request.httpMethod, let u = request.url {
            logLine = "\(meth) \(u) auth=\(authenticated) retry=\(retryCount)"
        }
        
        // copy the request and authenticate it. retain the original request for retries
        var actualRequest = decorateRequest(request)
            
        if authenticated {
            actualRequest = signRequest(actualRequest)
        }

        return session.dataTask(with: actualRequest, completionHandler: { (data, resp, err) -> Void in
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
                
                if authenticated && httpResp.isBreadChallenge {
                    self.log("\(logLine) got authentication challenge from API - will attempt to get token")
                    self.getToken { err in
                        if err != nil && retryCount < 1 { // retry once
                            self.log("\(logLine) error retrieving token: \(String(describing: err)) - will retry")
                            responseQueue.asyncAfter(deadline: DispatchTime(uptimeNanoseconds: 1)) {
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
                            responseQueue.async {
                                handler(data, httpResp, err)
                            }
                        }
                    }
                } else {
                    responseQueue.async {
                        handler(data, httpResp, err as NSError?)
                    }
                }
            } else {
                self.log("\(logLine) encountered connection error \(String(describing: err))")
                responseQueue.async {
                    handler(data, nil, err as NSError?)
                }
            }
        }) 
    }
    
    // retrieve a token and save it in the keychain data for this account
    private func getToken(_ handler: @escaping (NSError?) -> Void) {
        if isFetchingAuth {
            log("already fetching auth, waiting...")
            authFetchGroup.notify(queue: DispatchQueue.main) {
                handler(nil)
            }
            return
        }
        guard let authKey = authKey,
            let authPubKey = authKey.encodeAsPublic.hexToData else {
                return handler(NSError(domain: BRAPIClientErrorDomain, code: 500, userInfo: [
                    NSLocalizedDescriptionKey: S.ApiClient.notReady]))
        }
        isFetchingAuth = true
        log("auth: entering group")
        authFetchGroup.enter()
        var req = URLRequest(url: url("/token"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let reqJson = [
            "pubKey": authPubKey.base58,
            "deviceID": deviceId
        ]
        do {
            let dat = try JSONSerialization.data(withJSONObject: reqJson, options: [])
            req.httpBody = dat
        } catch let e {
            log("JSON Serialization error \(e)")
            isFetchingAuth = false
            authFetchGroup.leave()
            return handler(NSError(domain: BRAPIClientErrorDomain, code: 500, userInfo: [
                NSLocalizedDescriptionKey: S.ApiClient.jsonError]))
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
                            NSLocalizedDescriptionKey: S.ApiClient.tokenError]))
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
                            var kcData = self.authenticator.apiUserAccount ?? [AnyHashable: Any]()
                            kcData["token"] = tok
                            kcData["userID"] = uid
                            self.authenticator.apiUserAccount = kcData
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

    public func urlSession(_ session: URLSession,
                           task: URLSessionTask,
                           didReceive challenge: URLAuthenticationChallenge,
                           completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            if challenge.protectionSpace.host == host && challenge.protectionSpace.serverTrust != nil {
                log("URLSession challenge accepted!")
                completionHandler(.useCredential,
                    URLCredential(trust: challenge.protectionSpace.serverTrust!))
            } else {
                log("URLSession challenge rejected")
                completionHandler(.rejectProtectionSpace, nil)
            }
        }
    }
    
    public func urlSession(_ session: URLSession,
                           task: URLSessionTask,
                           willPerformHTTPRedirection response: HTTPURLResponse,
                           newRequest request: URLRequest,
                           completionHandler: @escaping (URLRequest?) -> Void) {
        var actualRequest = request
        if let currentReq = task.currentRequest, var curHost = currentReq.url?.host, let curScheme = currentReq.url?.scheme {
            if let curPort = currentReq.url?.port, curPort != 443 && curPort != 80 {
                curHost = "\(curHost):\(curPort)"
            }
            if curHost == host && curScheme == proto {
                // follow the redirect if we're interacting with our API
                actualRequest = decorateRequest(request)
                log("redirecting \(String(describing: currentReq.url)) to \(String(describing: request.url))")
                if let curAuth = currentReq.allHTTPHeaderFields?["Authorization"], curAuth.hasPrefix("bread") {
                    // add authentication because the previous request was authenticated
                    log("adding authentication to redirected request")
                    actualRequest = signRequest(actualRequest)
                }
                return completionHandler(actualRequest)
            }
        }
        completionHandler(nil)
    }
    
    func me(handler: @escaping (_ success: Bool, _ response: Data?, _ error: Error?) -> Void) {
        let req = URLRequest(url: url("/me"))
        let task = dataTaskWithRequest(req, authenticated: true, handler: { data, response, err in
            if let data = data {
                print("me: \(String(describing: String(data: data, encoding: .utf8)))")
            }
            let success = response?.statusCode == 200
            handler(success, data, err)
        })
        task.resume()
    }
}

extension Dictionary where Key == String, Value == String {
    func get(lowercasedKey k: String) -> String? {
        let lcKey = k.lowercased()
        if let v = self[lcKey] {
            return v
        }
        for (lk, v) in self {
            if lk.lowercased() == lcKey {
                return v
            }
        }
        return nil
    }
}

fileprivate extension URLRequest {
    var signingString: String {
        var parts = [
            httpMethod ?? "",
            "",
            allHTTPHeaderFields?.get(lowercasedKey: "content-type") ?? "",
            allHTTPHeaderFields?.get(lowercasedKey: "date") ?? "",
            url?.resourceString ?? ""
        ]
        if let meth = httpMethod {
            switch meth {
            case "POST", "PUT", "PATCH":
                if let d = httpBody, !d.isEmpty {
                    parts[1] = d.sha256.base58
                }
            default: break
            }
        }
        return parts.joined(separator: "\n")
    }
}

fileprivate extension HTTPURLResponse {
    var isBreadChallenge: Bool {
        if let headers = allHeaderFields as? [String: String],
            let challenge = headers.get(lowercasedKey: "www-authenticate") {
            if challenge.lowercased().hasPrefix("bread") {
                return true
            }
        }
        return false
    }
}

fileprivate extension URL {
    var resourceString: String {
        var urlStr = "\(path)"
        if let query = query {
            if query.lengthOfBytes(using: String.Encoding.utf8) > 0 {
                urlStr = "\(urlStr)?\(query)"
            }
        }
        return urlStr
    }
}
