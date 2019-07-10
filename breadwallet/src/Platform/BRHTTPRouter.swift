//
//  BRHTTPRouter.swift
//  BreadWallet
//
//  Created by Samuel Sutch on 2/8/16.
//  Copyright (c) 2016-2019 Breadwinner AG. All rights reserved.
//

import Foundation

// swiftlint:disable legacy_hashing

public typealias BRHTTPRouteMatch = [String: [String]]

public typealias BRHTTPRoute = (_ request: BRHTTPRequest, _ match: BRHTTPRouteMatch) throws -> BRHTTPResponse

public protocol BRHTTPRouterPlugin {
    func hook(_ router: BRHTTPRouter)
}

open class BRHTTPRoutePair {
    var method: String = "GET"
    var path: String = "/"
    var regex: NSRegularExpression
    var captureGroups: [Int: String]
    
    open var hashValue: Int {
        return method.hashValue ^ path.hashValue
    }
    
    init(method m: String, path p: String) {
        method = m.uppercased()
        path = p
        if !path.hasPrefix("/") {
            path = "/" + path
        }
        if path.hasSuffix("/") {
            path = String(path[..<path.index(path.endIndex, offsetBy: -1)])
        }
        let parts = path.components(separatedBy: "/")
        captureGroups = [Int: String]()
        var reParts = [String]()
        var i = 0
        for part in parts {
            if part.hasPrefix("(") && part.hasSuffix(")") {
                let w1 = part.index(part.endIndex, offsetBy: -2)
                let w2 = part.index(part.endIndex, offsetBy: -1)
                if String(part[w1..<w2]) == "*" { // a wild card capture (part*)
                    let i1 = part.index(part.startIndex, offsetBy: 1)
                    let i2 = part.index(part.endIndex, offsetBy: -2)
                    captureGroups[i] = String(part[i1..<i2])
                    reParts.append("(.*)")
                } else {
                    let i1 = part.index(part.startIndex, offsetBy: 1)
                    let i2 = part.index(part.endIndex, offsetBy: -1)
                    captureGroups[i] = String(part[i1..<i2])
                    reParts.append("([^/]+)") // a capture (part)
                }
                i += 1
            } else {
                reParts.append(part) // a non-captured component
            }
        }
        
        let re = "^" + reParts.joined(separator: "/") + "$"
        //print("\n\nroute: \n\n method: \(method)\n path: \(path)\n regex: \(re)\n captures: \(captureGroups)\n\n")
        guard let reg = try? NSRegularExpression(pattern: re, options: []) else {
            fatalError("unable to parse regex pattern: \(re)")
        }
        regex = reg
    }
    
    open func match(_ request: BRHTTPRequest) -> BRHTTPRouteMatch? {
        if request.method.uppercased() != method {
            return nil
        }
        var p = request.path // strip trailing slash
        if p.hasSuffix("/") {
            p = String(request.path[..<request.path.index(request.path.endIndex, offsetBy: -1)])
        }
        if let m = regex.firstMatch(in: request.path, options: [], range: NSRange(location: 0, length: p.count)), m.numberOfRanges - 1 == captureGroups.count {
                var match = BRHTTPRouteMatch()
                for i in 1..<m.numberOfRanges {
                    let key = captureGroups[i-1]!
                    let captured = (p as NSString).substring(with: m.range(at: i))
                    if match[key] == nil {
                        match[key] = [captured]
                    } else {
                        match[key]?.append(captured)
                    }
                }
                return match
        }
        return nil
    }
}

open class BRHTTPRouter: BRHTTPMiddleware {
    var routes = [(BRHTTPRoutePair, BRHTTPRoute)]()
    var plugins = [BRHTTPRouterPlugin]()
    fileprivate var wsServer = BRWebSocketServer()
    
    open func handle(_ request: BRHTTPRequest, next: @escaping (BRHTTPMiddlewareResponse) -> Void) {
        var response: BRHTTPResponse?
        
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
        self.get(pattern) { [weak client] (request, match) -> BRHTTPResponse in
            guard let theClient = client else { return BRHTTPResponse(request: request, code: 500) }
            self.wsServer.serveForever()
            let resp = BRHTTPResponse(async: request)
            let ws = BRWebSocketImpl(request: request, response: resp, match: match, client: theClient)
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
