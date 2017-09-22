//
//  BRAPIProxy.swift
//  BreadWallet
//
//  Created by Samuel Sutch on 2/8/16.
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

// Add this middleware to a BRHTTPServer to expose a proxy to the breadwallet HTTP api
// It has all the capabilities of the real API but with the ability to authenticate 
// requests using the users private keys stored on device.
//
// Clients should set the "X-Should-Authenticate" to sign requests with the users private authentication key
open class BRAPIProxy: BRHTTPMiddleware {
    var mountPoint: String
    var apiInstance: BRAPIClient
    var shouldAuthHeader: String = "x-should-authenticate"
    
    var bannedSendHeaders: [String] {
        return [
            shouldAuthHeader,
            "connection",
            "authorization",
            "host",
            "user-agent"
        ]
    }
    
    var bannedReceiveHeaders: [String] = ["content-length", "content-encoding", "connection"]
    
    init(mountAt: String, client: BRAPIClient) {
        mountPoint = mountAt
        if mountPoint.hasSuffix("/") {
            mountPoint = String(mountPoint[..<mountPoint.characters.index(mountPoint.endIndex, offsetBy: -1)])
        }
        apiInstance = client
    }
    
    open func handle(_ request: BRHTTPRequest, next: @escaping (BRHTTPMiddlewareResponse) -> Void) {
        if request.path.hasPrefix(mountPoint) {
            let idx = request.path.characters.index(request.path.startIndex, offsetBy: mountPoint.characters.count)
            var path = String(request.path[idx...])
            if request.queryString.utf8.count > 0 {
                path += "?\(request.queryString)"
            }
            var nsReq = URLRequest(url: apiInstance.url(path))
            nsReq.httpMethod = request.method
            // copy body
            if request.hasBody {
                nsReq.httpBody = request.body()
            }
            // copy headers
            for (hdrName, hdrs) in request.headers {
                if bannedSendHeaders.contains(hdrName) { continue }
                for hdr in hdrs {
                    nsReq.setValue(hdr, forHTTPHeaderField: hdrName)
                }
            }
            
            var auth = false
            if let authHeader = request.headers[shouldAuthHeader], authHeader.count > 0 {
                if authHeader[0].lowercased() == "yes" || authHeader[0].lowercased() == "true" {
                    auth = true
                }
            }
            apiInstance.dataTaskWithRequest(nsReq, authenticated: auth, retryCount: 0) { (data, nsHttpResponse, err) in
                    if let httpResp = nsHttpResponse, let headers = httpResp.allHeaderFields as? [String: String] {
                        var hdrs = [String: [String]]()
                        for (k, v) in headers {
                            if self.bannedReceiveHeaders.contains(k.lowercased()) { continue }
                            hdrs[k] = [v]
                        }
                        var body: [UInt8]? = nil
                        if let bod = data {
                            body = [UInt8](bod)
                        }
                        let resp = BRHTTPResponse(
                            request: request, statusCode: httpResp.statusCode,
                            statusReason: HTTPURLResponse.localizedString(forStatusCode: httpResp.statusCode),
                            headers: hdrs, body: body)
                        return next(BRHTTPMiddlewareResponse(request: request, response: resp))
                    } else {
                        print("[BRAPIProxy] error getting response from backend: \(String(describing: err))")
                        return next(BRHTTPMiddlewareResponse(request: request, response: nil))
                    }
            }.resume()
        } else {
            return next(BRHTTPMiddlewareResponse(request: request, response: nil))
        }
    }
}
