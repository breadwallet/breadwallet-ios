//
//  BRHTTPServer.swift
//  BreadWallet
//
//  Created by Samuel Sutch on 2/8/16.
//  Copyright (c) 2016-2019 Breadwinner AG. All rights reserved.
//

import UIKit

enum BRHTTPServerError: Error {
    case socketCreationFailed
    case socketBindFailed
    case socketListenFailed
    case socketRecvFailed
    case socketWriteFailed
    case invalidHttpRequest
    case invalidRangeHeader
}

public protocol BRHTTPMiddleware {
    func handle(_ request: BRHTTPRequest, next: @escaping (BRHTTPMiddlewareResponse) -> Void)
}

open class BRHTTPMiddlewareResponse {
    var request: BRHTTPRequest
    var response: BRHTTPResponse?
    
    init(request: BRHTTPRequest, response: BRHTTPResponse?) {
        self.request = request
        self.response = response
    }
}

@objc open class BRHTTPServer: NSObject {
    var fd: Int32 = -1
    var clients: Set<Int32> = []
    var middleware: [BRHTTPMiddleware] = [BRHTTPMiddleware]()
    var isStarted: Bool { return fd != -1 }
    var port: in_port_t = 0
    var listenAddress: String = "127.0.0.1"
    private var isShutdownCancelled = false
    var Q: DispatchQueue = {
        return DispatchQueue(label: "br_http_server", attributes: DispatchQueue.Attributes.concurrent)
    }()
    
    func prependMiddleware(middleware mw: BRHTTPMiddleware) {
        middleware.insert(mw, at: 0)
    }
    
    func appendMiddleware(middle mw: BRHTTPMiddleware) {
        middleware.append(mw)
    }
    
    func resetMiddleware() {
        middleware.removeAll()
    }
    
    func start() throws {
        for i in 0 ..< 100 {
            // get a random port
            
            let port = E.isDebug ? in_port_t(12345+Int(i)) : in_port_t(arc4random() % (49152 - 1024) + 1024)
            
            do {
                try listenServer(port)
                self.port = port
                let nc = NotificationCenter.default
                // backgrounding
                nc.addObserver(self, selector: #selector(BRHTTPServer.suspend(_:)),
                               name: UIApplication.willResignActiveNotification, object: nil)
                // foregrounding
                nc.addObserver(self, selector: #selector(BRHTTPServer.resume(_:)),
                               name: UIApplication.didBecomeActiveNotification, object: nil)
                return
            } catch {
                continue
            }
        }
        throw BRHTTPServerError.socketBindFailed
    }
    
    func listenServer(_ port: in_port_t, maxPendingConnections: Int32 = SOMAXCONN) throws {
        shutdownServer()
        
        let sfd = socket(AF_INET, SOCK_STREAM, 0)
        if sfd == -1 {
            throw BRHTTPServerError.socketCreationFailed
        }
        var v: Int32 = 1
        if setsockopt(sfd, SOL_SOCKET, SO_REUSEADDR, &v, socklen_t(MemoryLayout<Int32>.size)) == -1 {
            _ = Darwin.shutdown(sfd, SHUT_RDWR)
            close(sfd)
            throw BRHTTPServerError.socketCreationFailed
        }
        v = 1
        setsockopt(sfd, SOL_SOCKET, SO_NOSIGPIPE, &v, socklen_t(MemoryLayout<Int32>.size))
        var addr = sockaddr_in()
        addr.sin_len = __uint8_t(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = Int(OSHostByteOrder()) == OSLittleEndian ? _OSSwapInt16(port) : port
        addr.sin_addr = in_addr(s_addr: inet_addr(listenAddress))
        addr.sin_zero = (0, 0, 0, 0, 0, 0, 0, 0)
        
        var bind_addr = sockaddr()
        memcpy(&bind_addr, &addr, Int(MemoryLayout<sockaddr_in>.size))
        
        if bind(sfd, &bind_addr, socklen_t(MemoryLayout<sockaddr_in>.size)) == -1 {
            perror("bind error")
            _ = Darwin.shutdown(sfd, SHUT_RDWR)
            close(sfd)
            throw BRHTTPServerError.socketBindFailed
        }
        
        if listen(sfd, maxPendingConnections) == -1 {
            perror("listen error")
            _ = Darwin.shutdown(sfd, SHUT_RDWR)
            close(sfd)
            throw BRHTTPServerError.socketListenFailed
        }
        
        fd = sfd
        acceptClients()
        print("[BRHTTPServer] listening on \(port)")
    }
    
    func shutdownServer() {
        _ = Darwin.shutdown(fd, SHUT_RDWR)
        close(fd)
        fd = -1
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        for cli_fd in self.clients {
            _ = Darwin.shutdown(cli_fd, SHUT_RDWR)
        }
        self.clients.removeAll(keepingCapacity: true)
        print("[BRHTTPServer] no longer listening")
    }
    
    func stop() {
        shutdownServer()
        let nc = NotificationCenter.default
        // background
        nc.removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil)
        // foreground
        nc.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    @objc func suspend(_: Notification) {
        if isStarted {
            objc_sync_enter(self)
            defer { objc_sync_exit(self) }
            isShutdownCancelled = false
            if self.clients.isEmpty {
                shutdownServer()
                print("[BRHTTPServer] suspended")
            } else {
                // give it 500ms to complete, then kill it
                print("[BRHTTPServer] suspending: waiting for clients")
                Q.asyncAfter(deadline: .now() + .milliseconds(500)) { [weak self] in
                    guard let myself = self else { return }
                    objc_sync_enter(myself)
                    defer { objc_sync_exit(myself) }
                    guard !myself.isShutdownCancelled else { return print("[BRHTTPServer] suspending cancelled") }
                    myself.shutdownServer()
                    print("[BRHTTPServer] suspended")
                }
            }
        } else {
            print("[BRHTTPServer] already suspended")
        }
    }

    @objc func resume(_: Notification) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        isShutdownCancelled = true
        if !isStarted {
            do {
                try listenServer(port)
                print("[BRHTTPServer] resumed")
            } catch let e {
                print("[BRHTTPServer] unable to start \(e)")
            }
        } else {
            print("[BRHTTPServer] already resumed")
        }
    }
    
    func addClient(_ cli_fd: Int32) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        clients.insert(cli_fd)
    }
    
    func rmClient(_ cli_fd: Int32) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        clients.remove(cli_fd)
    }
    
    fileprivate func acceptClients() {
        Q.async {
            while true {
                var addr = sockaddr(sa_len: 0, sa_family: 0, sa_data: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
                var len: socklen_t = 0
                let cli_fd = accept(self.fd, &addr, &len)
                if cli_fd == -1 {
                    break
                }
                var v: Int32 = 1
                setsockopt(cli_fd, SOL_SOCKET, SO_NOSIGPIPE, &v, socklen_t(MemoryLayout<Int32>.size))
                self.addClient(cli_fd)
                self.Q.async {
                    while let req = try? BRHTTPRequestImpl(readFromFd: cli_fd, queue: self.Q) {
                        self.dispatch(middleware: self.middleware, req: req) { _ in
                            _ = Darwin.shutdown(cli_fd, SHUT_RDWR)
                            close(cli_fd)
                            self.rmClient(cli_fd)
                        }
                        if !req.isKeepAlive { break }
                    }
                }
            }
        }
    }
    // curl http://localhost:30079/_api/exchange -H 'X-Should-Authenticate: true' -H 'Accept: application/json'
    fileprivate func dispatch(middleware mw: [BRHTTPMiddleware], req: BRHTTPRequest, finish: @escaping (BRHTTPResponse) -> Void) {
        var newMw = mw
        if let curMw = newMw.popLast() {
            curMw.handle(req, next: { mwResp in
                print("[BRHTTPServer] handling middleware = \(type(of: curMw))")
                if let httpResp = mwResp.response {
                    httpResp.done {
                        do {
                            try httpResp.send()
                            self.logline(req, response: httpResp)
                        } catch let e {
                            print("[BRHTTPServer] error sending response. request: \(req) error: \(e)")
                        }
                        finish(httpResp)
                    }
                } else {
                    self.dispatch(middleware: newMw, req: mwResp.request, finish: finish)
                }
            })
        } else {
            let resp = BRHTTPResponse(
                request: req, statusCode: 404, statusReason: "Not Found", headers: nil, body: nil)
            logline(req, response: resp)
            _ = try? resp.send()
            finish(resp)
        }
    }
    
    fileprivate func logline(_ request: BRHTTPRequest, response: BRHTTPResponse) {
        let ms = Double(round((request.start.timeIntervalSinceNow * -1000.0)*1000)/1000)
        let b = response.body?.count ?? 0
        let c = response.statusCode ?? -1
        let s = response.statusReason ?? "Unknown"
        print("[BRHTTPServer] \(request.method) \(request.path) -> \(c) \(s) \(b)b in \(ms)ms")
    }
}

public protocol BRHTTPRequest {
    var fd: Int32 { get }
    var queue: DispatchQueue { get }
    var method: String { get }
    var path: String { get }
    var queryString: String { get }
    var query: [String: [String]] { get }
    var headers: [String: [String]] { get }
    var isKeepAlive: Bool { get }
    func body() -> Data?
    var hasBody: Bool { get }
    var contentType: String { get }
    var contentLength: Int { get }
    var start: Date { get }
    func json() -> AnyObject?
}

open class BRHTTPRequestImpl: BRHTTPRequest {
    open var fd: Int32
    open var queue: DispatchQueue
    open var method = "GET"
    open var path = "/"
    open var queryString = ""
    open var query = [String: [String]]()
    open var headers = [String: [String]]()
    open var start = Date()
    
    open var isKeepAlive: Bool {
        return (headers["connection"] != nil
            && headers["connection"]?.count ?? 0 > 0
            && headers["connection"]![0] == "keep-alive")
    }
    
    static let rangeRe = (try? NSRegularExpression(pattern: "bytes=(\\d*)-(\\d*)", options: .caseInsensitive)) ?? NSRegularExpression()
    
    public required init(fromRequest r: BRHTTPRequest) {
        fd = r.fd
        queue = r.queue
        method = r.method
        path = r.path
        queryString = r.queryString
        query = r.query
        headers = r.headers
        if let ri = r as? BRHTTPRequestImpl {
            _bodyRead = ri._bodyRead
            _body = ri._body
        }
    }
    
    public required init(readFromFd: Int32, queue: DispatchQueue) throws {
        fd = readFromFd
        self.queue = queue
        let status = try readLine()
        let statusParts = status.components(separatedBy: " ")
        if statusParts.count < 3 {
            throw BRHTTPServerError.invalidHttpRequest
        }
        method = statusParts[0]
        path = statusParts[1]
        // parse query string
        if path.range(of: "?") != nil {
            let parts = path.components(separatedBy: "?")
            path = parts[0]
            queryString = parts[1..<parts.count].joined(separator: "?")
            let pairs = queryString.components(separatedBy: "&")
            for pair in pairs {
                let pairSides = pair.components(separatedBy: "=")
                if pairSides.count == 2 {
                    if query[pairSides[0]] != nil {
                        query[pairSides[0]]?.append(pairSides[1])
                    } else {
                        query[pairSides[0]] = [pairSides[1]]
                    }
                }
            }
        }
        // parse headers
        while true {
            let hdr = try readLine()
            if hdr.isEmpty { break }
            let hdrParts = hdr.components(separatedBy: ":")
            if hdrParts.count >= 2 {
                let name = hdrParts[0].lowercased()
                let hdrVal = hdrParts[1..<hdrParts.count].joined(separator: ":").trimmingCharacters(
                    in: CharacterSet.whitespaces)
                if headers[name] != nil {
                    headers[name]?.append(hdrVal)
                } else {
                    headers[name] = [hdrVal]
                }
            }
        }
    }
    
    func readLine() throws -> String {
        var chars: String = ""
        var n = 0
        repeat {
            n = self.read()
            if n > 13 /* CR */ { chars.append(Character(UnicodeScalar(n)!)) }
        } while n > 0 && n != 10 /* NL */
        if n == -1 {
            throw BRHTTPServerError.socketRecvFailed
        }
        return chars
    }
    
    func read() -> Int {
        var buf = [UInt8](repeating: 0, count: 1)
        let n = recv(fd, &buf, 1, 0)
        if n <= 0 {
            return n
        }
        return Int(buf[0])
    }
    
    open var hasBody: Bool {
        return method == "POST" || method == "PATCH" || method == "PUT"
    }
    
    open var contentLength: Int {
        if let hdrs = headers["content-length"], hasBody && !hdrs.isEmpty {
            if let i = Int(hdrs[0]) {
                return i
            }
        }
        return 0
    }
    
    open var contentType: String {
        if let hdrs = headers["content-type"], !hdrs.isEmpty { return hdrs[0] }
        return "application/octet-stream"
    }
    
    fileprivate var _body: [UInt8]?
    fileprivate var _bodyRead: Bool = false
    
    open func body() -> Data? {
        if _bodyRead && _body != nil {
            let bp = UnsafeMutablePointer<UInt8>(UnsafeMutablePointer(mutating: _body!))
            return Data(bytesNoCopy: bp, count: contentLength, deallocator: .none)
        }
        guard !_bodyRead else { return nil }
        guard contentLength > 0 else { return nil }
        let buffSize = 4096
        var body = [UInt8]()
        var buf = [UInt8](repeating: 0, count: buffSize)
        var total = 0
        while true {
            let n = recv(fd, &buf, buffSize, 0)
            total += n
            if n < buffSize {
                _bodyRead = true
            }
            body += buf[0..<n]
            if _bodyRead || total >= contentLength {
                break
            }
        }
        _body = body
        let bp = UnsafeMutablePointer<UInt8>(UnsafeMutablePointer(mutating: _body!))
        return Data(bytesNoCopy: bp, count: contentLength, deallocator: .none)
    }
    
    open func json() -> AnyObject? {
        if let b = body() {
            if let j = try? JSONSerialization.jsonObject(with: b, options: []) {
                return j as AnyObject?
            }
        }
        return nil
    }
    
    func rangeHeader() throws -> (Int, Int)? {
        if headers["range"] == nil {
            return nil
        }
        guard let rngHeader = headers["range"]?[0],
            let match = BRHTTPRequestImpl.rangeRe.matches(in: rngHeader, options: .anchored, range:
                NSRange(location: 0, length: rngHeader.count)).first, match.numberOfRanges == 3 else {
                throw BRHTTPServerError.invalidRangeHeader
        }
        let startStr = (rngHeader as NSString).substring(with: match.range(at: 1))
        let endStr = (rngHeader as NSString).substring(with: match.range(at: 2))
        guard let start = Int(startStr), let end = Int(endStr) else {
            throw BRHTTPServerError.invalidRangeHeader
        }
        return (start, end)
    }
}

open class BRHTTPResponse {
    var request: BRHTTPRequest
    var statusCode: Int?
    var statusReason: String?
    var headers: [String: [String]]?
    var body: [UInt8]?
    
    var async = false
    var onDone: (() -> Void)?
    var isDone = false
    var isKilled = false
    
    static var reasonMap: [Int: String] = [
        100: "Continue",
        101: "Switching Protocols",
        200: "OK",
        201: "Created",
        202: "Accepted",
        203: "Non-Authoritative Information",
        204: "No Content",
        205: "Reset Content",
        206: "Partial Content",
        207: "Multi Status",
        208: "Already Reported",
        226: "IM Used",
        300: "Multiple Choices",
        301: "Moved Permanently",
        302: "Found",
        303: "See Other",
        304: "Not Modified",
        305: "Use Proxy",
        306: "Switch Proxy", // unused in spec
        307: "Temporary Redirect",
        308: "Permanent Redirect",
        400: "Bad Request",
        401: "Unauthorized",
        402: "Payment Required",
        403: "Forbidden",
        404: "Not Found",
        405: "Method Not Allowed",
        406: "Not Acceptable",
        407: "Proxy Authentication Required",
        408: "Request Timeout",
        409: "Conflict",
        410: "Gone",
        411: "Length Required",
        412: "Precondition Failed",
        413: "Request Entity Too Large",
        414: "Request-URI Too Long",
        415: "Unsupported Media Type",
        416: "Request Range Not Satisfiable",
        417: "Expectation Failed",
        418: "I'm a teapot",
        421: "Misdirected Request",
        422: "Unprocessable Entity",
        423: "Locked",
        424: "Failed Dependency",
        426: "Upgrade Required",
        428: "Precondition Required",
        429: "Too Many Requests",
        431: "Request Header Fields Too Large",
        451: "Unavailable For Leagal Reasons",
        500: "Internal Server Error",
        501: "Not Implemented",
        502: "Bad Gateway",
        503: "Service Unavailable",
        504: "Gateway Timeout",
        505: "HTTP Version Not Supported",
        506: "Variant Also Negotiates",
        507: "Insufficient Storage",
        508: "Loop Detected",
        510: "Not Extended",
        511: "Network Authentication Required"
        
    ]
    
    init(request: BRHTTPRequest, statusCode: Int?, statusReason: String?, headers: [String: [String]]?, body: [UInt8]?) {
        self.request = request
        self.statusCode = statusCode
        self.statusReason = statusReason
        self.headers = headers
        self.body = body
        self.isDone = true
    }
    
    init(async request: BRHTTPRequest) {
        self.request = request
        self.async = true
    }
    
    convenience init(request: BRHTTPRequest, code: Int) {
        self.init(
            request: request, statusCode: code, statusReason: BRHTTPResponse.reasonMap[code], headers: nil, body: nil)
    }
    
    convenience init(request: BRHTTPRequest, code: Int, json j: Any) throws {
        let jsonData = try JSONSerialization.data(withJSONObject: j, options: [])
        let bp = (jsonData as NSData).bytes.bindMemory(to: UInt8.self, capacity: jsonData.count)
        let bodyBuffer = UnsafeBufferPointer<UInt8>(start: bp, count: jsonData.count)
        self.init(
            request: request, statusCode: code, statusReason: BRHTTPResponse.reasonMap[code],
            headers: ["Content-Type": ["application/json"]], body: Array(bodyBuffer))
    }
    
    func send() throws {
        if isKilled {
            return // do nothing... the connection should just be closed
        }
        let status = statusCode ?? 200
        let reason = statusReason ?? "OK"
        try writeUTF8("HTTP/1.1 \(status) \(reason)\r\n")
        
        let length = body?.count ?? 0
        try writeUTF8("Content-Length: \(length)\r\n")
        if request.isKeepAlive {
            try writeUTF8("Connection: keep-alive\r\n")
        }
        let hdrs = headers ?? [String: [String]]()
        for (n, v) in hdrs {
            for yv in v {
                try writeUTF8("\(n): \(yv)\r\n")
            }
        }
        
        try writeUTF8("\r\n")
        
        if let b = body {
            try writeUInt8(b)
        }
    }
    
    func writeUTF8(_ s: String) throws {
        try writeUInt8([UInt8](s.utf8))
    }
    
    func writeUInt8(_ data: [UInt8]) throws {
        try data.withUnsafeBufferPointer { pointer in
            var sent = 0
            while sent < data.count {
                let s = write(request.fd, pointer.baseAddress! + sent, Int(data.count - sent))
                if s <= 0 {
                    throw BRHTTPServerError.socketWriteFailed
                }
                sent += s
            }
        }
    }
    
    func provide(_ status: Int) {
        objc_sync_enter(self)
        if isDone {
            print("ERROR: can not call provide() on async HTTP response more than once!")
            return
        }
        isDone = true
        objc_sync_exit(self)
        statusCode = status
        statusReason = BRHTTPResponse.reasonMap[status]
        objc_sync_enter(self)
        isDone = true
        if self.onDone != nil {
            self.onDone!()
        }
        objc_sync_exit(self)
    }
    
    func provide(_ status: Int, json: Any?) {
        objc_sync_enter(self)
        if isDone {
            print("ERROR: can not call provide() on async HTTP response more than once!")
            return
        }
        isDone = true
        objc_sync_exit(self)
        do {
            if let json = json {
                let jsonData = try JSONSerialization.data(withJSONObject: json, options: [])
                let bp = (jsonData as NSData).bytes.bindMemory(to: UInt8.self, capacity: jsonData.count)
                let bodyBuffer = UnsafeBufferPointer<UInt8>(start: bp, count: jsonData.count)
                headers = ["Content-Type": ["application/json"]]
                body = Array(bodyBuffer)
            }
            statusCode = status
            statusReason = BRHTTPResponse.reasonMap[status]
        } catch let e {
            print("Async http response provider threw exception \(e)")
            statusCode = 500
            statusReason = BRHTTPResponse.reasonMap[500]
        }
        objc_sync_enter(self)
        isDone = true
        if self.onDone != nil {
            self.onDone!()
        }
        objc_sync_exit(self)
    }
    
    func provide(_ status: Int, data: [UInt8], contentType: String) {
        objc_sync_enter(self)
        if isDone {
            print("ERROR: can not call provide() on async HTTP response more than once!")
            return
        }
        isDone = true
        objc_sync_exit(self)
        headers = ["Content-Type": [contentType]]
        body = data
        statusCode = status
        statusReason = BRHTTPResponse.reasonMap[status]
        objc_sync_enter(self)
        isDone = true
        if self.onDone != nil {
            self.onDone!()
        }
        objc_sync_exit(self)
    }
    
    func kill() {
        objc_sync_enter(self)
        if isDone {
            print("ERROR: can not call kill() on async HTTP response more than once!")
            return
        }
        isDone = true
        isKilled = true
        if self.onDone != nil {
            self.onDone!()
        }
        objc_sync_exit(self)
    }
    
    func done(_ onDone: @escaping () -> Void) {
        objc_sync_enter(self)
        self.onDone = onDone
        if self.isDone {
            self.onDone!()
        }
        objc_sync_exit(self)
    }
}
