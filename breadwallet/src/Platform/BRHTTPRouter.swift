//
//  BRHTTPRouter.swift
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


public typealias BRHTTPRouteMatch = [String: [String]]

public typealias BRHTTPRoute = (_ request: BRHTTPRequest, _ match: BRHTTPRouteMatch) throws -> BRHTTPResponse

@objc public protocol BRHTTPRouterPlugin {
    func hook(_ router: BRHTTPRouter)
}

@objc open class BRHTTPRoutePair: NSObject {
    open var method: String = "GET"
    open var path: String = "/"
    open var regex: NSRegularExpression!
    var captureGroups: [Int: String]!
    
    override open var hashValue: Int {
        return method.hashValue ^ path.hashValue
    }
    
    init(method m: String, path p: String) {
        method = m.uppercased()
        path = p
        super.init()
        parse()
    }
    
    fileprivate func parse() {
        if !path.hasPrefix("/") {
            path = "/" + path
        }
        if path.hasSuffix("/") {
            path = path.substring(to: path.characters.index(path.endIndex, offsetBy: -1))
        }
        let parts = path.components(separatedBy: "/")
        captureGroups = [Int: String]()
        var reParts = [String]()
        var i = 0
        for part in parts {
            if part.hasPrefix("(") && part.hasSuffix(")") {
                let w1 = part.characters.index(part.endIndex, offsetBy: -2)
                let w2 = part.characters.index(part.endIndex, offsetBy: -1)
                if part.substring(with: w1..<w2) == "*" { // a wild card capture (part*)
                    let i1 = part.characters.index(part.startIndex, offsetBy: 1)
                    let i2 = part.characters.index(part.endIndex, offsetBy: -2)
                    captureGroups[i] = part.substring(with: i1..<i2)
                    reParts.append("(.*)")
                } else {
                    let i1 = part.characters.index(part.startIndex, offsetBy: 1)
                    let i2 = part.characters.index(part.endIndex, offsetBy: -1)
                    captureGroups[i] = part.substring(with: i1..<i2)
                    reParts.append("([^/]+)") // a capture (part)
                }
                i += 1
            } else {
                reParts.append(part) // a non-captured component
            }
        }
        
        let re = "^" + reParts.joined(separator: "/") + "$"
        //print("\n\nroute: \n\n method: \(method)\n path: \(path)\n regex: \(re)\n captures: \(captureGroups)\n\n")
        regex = try! NSRegularExpression(pattern: re, options: [])
    }
    
    open func match(_ request: BRHTTPRequest) -> BRHTTPRouteMatch? {
        if request.method.uppercased() != method {
            return nil
        }
        var p = request.path // strip trailing slash
        if p.hasSuffix("/") {
            p = request.path.substring(to: request.path.characters.index(request.path.endIndex, offsetBy: -1))
        }
        if let m = regex.firstMatch(in: request.path, options: [], range: NSMakeRange(0, p.characters.count))
            , m.numberOfRanges - 1 == captureGroups.count {
                var match = BRHTTPRouteMatch()
                for i in 1..<m.numberOfRanges {
                    let key = captureGroups[i-1]!
                    let captured = (p as NSString).substring(with: m.rangeAt(i))
                    if match[key] == nil {
                        match[key] = [captured]
                    } else {
                        match[key]?.append(captured)
                    }
                    //print("capture range: '\(key)' = '\(captured)'\n\n")
                }
                return match
        }
        return nil
    }
}

@objc open class BRHTTPRouter: NSObject, BRHTTPMiddleware {
    var routes = [(BRHTTPRoutePair, BRHTTPRoute)]()
    var plugins = [BRHTTPRouterPlugin]()
    fileprivate var wsServer = BRWebSocketServer()
    
    open func handle(_ request: BRHTTPRequest, next: @escaping (BRHTTPMiddlewareResponse) -> Void) {
        var response: BRHTTPResponse? = nil
        
        for (routePair, route) in routes {
            if let match = routePair.match(request) {
                do {
                    response = try route(request, match)
                } catch let e {
                    print("[BRHTTPRouter] route \(routePair.method) \(routePair.path) threw an exception \(e)")
                    response = BRHTTPResponse(request: request, code: 500)
                }
                break
            }
        }
        
        return next(BRHTTPMiddlewareResponse(request: request, response: response))
    }
    
    open func get(_ pattern: String, route: @escaping BRHTTPRoute) {
        routes.append((BRHTTPRoutePair(method: "GET", path: pattern), route))
    }
    
    open func post(_ pattern: String, route: @escaping BRHTTPRoute) {
        routes.append((BRHTTPRoutePair(method: "POST", path: pattern), route))
    }
    
    open func put(_ pattern: String, route: @escaping BRHTTPRoute) {
        routes.append((BRHTTPRoutePair(method: "PUT", path: pattern), route))
    }
    
    open func patch(_ pattern: String, route: @escaping BRHTTPRoute) {
        routes.append((BRHTTPRoutePair(method: "PATCH", path: pattern), route))
    }
    
    open func delete(_ pattern: String, route: @escaping BRHTTPRoute) {
        routes.append((BRHTTPRoutePair(method: "DELETE", path: pattern), route))
    }
    
    open func any(_ pattern: String, route: @escaping BRHTTPRoute) {
        for m in ["GET", "POST", "PUT", "PATCH", "DELETE"] {
            routes.append((BRHTTPRoutePair(method: m, path: pattern), route))
        }
    }
    
    open func websocket(_ pattern: String, client: BRWebSocketClient) {
        self.get(pattern) { (request, match) -> BRHTTPResponse in
            self.wsServer.serveForever()
            let resp = BRHTTPResponse(async: request)
            let ws = BRWebSocketImpl(request: request, response: resp, match: match, client: client)
            if !ws.handshake() {
                print("[BRHTTPRouter] websocket - invalid handshake")
                resp.provide(400, json: ["error": "invalid handshake"])
            } else {
                self.wsServer.add(ws)
            }
            return resp
        }
    }
    
    open func plugin(_ plugin: BRHTTPRouterPlugin) {
        plugin.hook(self)
        plugins.append(plugin)
    }
    
    open func printDebug() {
        for (r, _) in routes {
            print("[BRHTTPRouter] \(r.method) \(r.path)")
        }
    }
}
