//
//  BRWebSocket.swift
//  BreadWallet
//
//  Created by Samuel Sutch on 2/18/16.
//  Copyright (c) 2016-2019 Breadwinner AG. All rights reserved.
//

import Foundation
import BRSocketHelpers

public protocol BRWebSocket {
    var id: String { get }
    var request: BRHTTPRequest { get }
    var match: BRHTTPRouteMatch { get }
    func send(_ text: String)
}

public protocol BRWebSocketClient: class {
    func socketDidConnect(_ socket: BRWebSocket)
    func socket(_ socket: BRWebSocket, didReceiveData data: Data)
    func socket(_ socket: BRWebSocket, didReceiveText text: String)
    func socketDidDisconnect(_ socket: BRWebSocket)
}

let GID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

enum SocketState {
    case headerb1
    case headerb2
    case lengthshort
    case lengthlong
    case mask
    case payload
}

enum SocketOpcode: UInt8, CustomStringConvertible {
    case stream = 0x0
    case text = 0x1
    case binary = 0x2
    case close = 0x8
    case ping = 0x9
    case pong = 0xA
    
    var description: String {
        switch self {
        case .stream: return "STREAM"
        case .text: return "TEXT"
        case .binary: return "BINARY"
        case .close: return "CLOSE"
        case .ping: return "PING"
        case .pong: return "PONG"
        }
    }
}

let (MAXHEADER, MAXPAYLOAD) = (65536, 33554432)

enum SocketCloseEventCode: UInt16 {
    case close_NORMAL = 1000
    case close_GOING_AWAY = 1001
    case close_PROTOCOL_ERROR = 1002
    case close_UNSUPPORTED = 1003
    case close_NO_STATUS = 1005
    case close_ABNORMAL = 1004
    case unsupportedData = 1006
    case policyViolation = 1007
    case close_TOO_LARGE = 1008
    case missingExtension = 1009
    case internalError = 1010
    case serviceRestart = 1011
    case tryAgainLater = 1012
    case tlsHandshake = 1015
}

class BRWebSocketServer {
    var sockets = [Int32: BRWebSocketImpl]()
    var thread: pthread_t?
    var waiter: UnsafeMutablePointer<pthread_cond_t>
    var mutex: UnsafeMutablePointer<pthread_mutex_t>
    
    init() {
        mutex = UnsafeMutablePointer.allocate(capacity: MemoryLayout<pthread_mutex_t>.size)
        waiter = UnsafeMutablePointer.allocate(capacity: MemoryLayout<pthread_cond_t>.size)
        pthread_mutex_init(mutex, nil)
        pthread_cond_init(waiter, nil)
    }
    
    func add(_ socket: BRWebSocketImpl) {
        log("adding socket \(socket.fd)")
        pthread_mutex_lock(mutex)
        sockets[socket.fd] = socket
        socket.client?.socketDidConnect(socket)
        pthread_cond_broadcast(waiter)
        pthread_mutex_unlock(mutex)
        log("done adding socket \(socket.fd)")
    }
    
    func serveForever() {
        objc_sync_enter(self)
        if thread != nil {
            objc_sync_exit(self)
            return
        }
        let selfPointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        pthread_create(&thread, nil, { (sillySelf: UnsafeMutableRawPointer) in
            let localSelf = Unmanaged<BRWebSocketServer>.fromOpaque(sillySelf).takeUnretainedValue()
            localSelf.log("in server thread")
            localSelf._serveForever()
            return nil
        }, selfPointer)
        objc_sync_exit(self)
    }
    
    func _serveForever() {
        log("starting websocket poller")
        while true {
            pthread_mutex_lock(mutex)
            while sockets.count < 1 {
                log("awaiting clients")
                pthread_cond_wait(waiter, mutex)
            }
            pthread_mutex_unlock(mutex)
            // log("awaiting select")
            
            // all fds should be available for a read
            let readFds = sockets.map({ (ws) -> Int32 in return ws.0 })
            
            // only fds which have items in the send queue are available for a write
            let writeFds = sockets.map({ (ws) -> Int32 in
                return ws.1.sendq.isEmpty ? -1 : ws.0
            }).filter({ i in return i != -1 })
            
            // build the select request and execute it, checking the result for an error
            let req = bw_select_request(
                write_fd_len: Int32(writeFds.count),
                read_fd_len: Int32(readFds.count),
                write_fds: UnsafeMutablePointer(mutating: writeFds),
                read_fds: UnsafeMutablePointer(mutating: readFds))
            
            let resp = bw_select(req)
            
            if resp.error > 0 {
                let errstr = strerror(resp.error)
                log("error doing a select \(String(describing: errstr)) - removing all clients")
                sockets.removeAll()
                continue
            }
            
            // read for all readers that have data waiting
            for i in 0..<resp.read_fd_len {
                if let readSock = sockets[resp.read_fds[Int(i)]] {
                    log("handle read fd \(readSock.fd)")
                    do {
                        try readSock.handleRead()
                    } catch {
                        readSock.response.kill()
                        readSock.client?.socketDidDisconnect(readSock)
                        sockets.removeValue(forKey: readSock.fd)
                    }
                } else {
                    log("nil read socket")
                }
            }
            
            // write for all writers
            for i in 0..<resp.write_fd_len {
                if let writeSock = sockets[resp.write_fds[Int(i)]] {
                    log("handle write fd=\(writeSock.fd)")
                    let (opcode, payload) = writeSock.sendq.removeFirst()
                    do {
                        let sentBytes = try sendBuffer(writeSock.fd, buffer: payload)
                        if sentBytes != payload.count {
                            let remaining = Array(payload.suffix(from: sentBytes - 1))
                            writeSock.sendq.insert((opcode, remaining), at: 0)
                            break // terminate sends and continue sending on the next select
                        } else {
                            if opcode == .close {
                                log("KILLING fd=\(writeSock.fd)")
                                writeSock.response.kill()
                                writeSock.client?.socketDidDisconnect(writeSock)
                                sockets.removeValue(forKey: writeSock.fd)
                                continue // go to the next select client
                            }
                        }
                    } catch {
                        // close...
                        writeSock.response.kill()
                        writeSock.client?.socketDidDisconnect(writeSock)
                        sockets.removeValue(forKey: writeSock.fd)
                    }
                } else {
                    log("nil write socket")
                }
            }
            
            // kill sockets that wrote out of bound data
            for i in 0..<resp.error_fd_len {
                if let errSock = sockets[resp.error_fds[Int(i)]] {
                    errSock.response.kill()
                    errSock.client?.socketDidDisconnect(errSock)
                    sockets.removeValue(forKey: errSock.fd)
                }
            }
        }
    }
    
    // attempt to send a buffer, returning the number of sent bytes
    func sendBuffer(_ fd: Int32, buffer: [UInt8]) throws -> Int {
        log("send buffer fd=\(fd) buffer=\(buffer)")
        var sent = 0
        try buffer.withUnsafeBufferPointer { pointer in
            while sent < buffer.count {
                let s = send(fd, pointer.baseAddress! + sent, Int(buffer.count - sent), 0)
                log("write result \(s)")
                if s <= 0 {
                    let serr = Int32(s)
                    // full buffer, should try again next iteration
                    if Int32(serr) == EWOULDBLOCK || Int32(serr) == EAGAIN {
                        return
                    } else {
                        self.log("socket write failed fd=\(fd) err=\(String(describing: strerror(serr)))")
                        throw BRHTTPServerError.socketWriteFailed
                    }
                }
                sent += s
            }
        }
        return sent
    }
    
    func log(_ s: String) {
        print("[BRWebSocketHost] \(s)")
    }
}

// swiftlint:disable type_body_length

class BRWebSocketImpl: BRWebSocket {
    var request: BRHTTPRequest
    var response: BRHTTPResponse
    var match: BRHTTPRouteMatch
    weak var client: BRWebSocketClient?
    var fd: Int32
    var key: String!
    var version: String!
    var id: String = UUID().uuidString
    
    var state = SocketState.headerb1
    var fin: UInt8 = 0
    var hasMask = false
    var opcode = SocketOpcode.stream
    var closed = false
    var index = 0
    var length = 0
    var lengtharray = [UInt8]()
    var lengtharrayWritten = 0
    var data = [UInt8]()
    var dataWritten = 0
    var maskarray = [UInt8]()
    var maskarrayWritten = 0
    
    var fragStart = false
    var fragType = SocketOpcode.binary
    var fragBuffer = [UInt8]()
    
    var sendq = [(SocketOpcode, [UInt8])]()
    
    init(request: BRHTTPRequest, response: BRHTTPResponse, match: BRHTTPRouteMatch, client: BRWebSocketClient) {
        self.request = request
        self.match = match
        self.fd = request.fd
        self.response = response
        self.client = client
    }
    
    // MARK: - public interface impl
    
    @objc func send(_ text: String) {
        sendMessage(false, opcode: .text, data: [UInt8](text.utf8))
    }
    
    // MARK: - private interface
    
    func handshake() -> Bool {
        log("handshake initiated")
        if let upgrades = request.headers["upgrade"], !upgrades.isEmpty {
            let upgrade = upgrades[0]
            if upgrade.lowercased() == "websocket" {
                if let ks = request.headers["sec-websocket-key"], let vs = request.headers["sec-websocket-version"], !ks.isEmpty && !vs.isEmpty {
                    key = ks[0]
                    version = vs[0]
                    do {
                        let acceptStr = "\(key!)\(GID)"
                        if let acceptStrBytes = acceptStr.data(using: .utf8) {
                            let acceptEncodedStr = acceptStrBytes.sha1.base64EncodedData()
                            try response.writeUTF8("HTTP/1.1 101 Switching Protocols\r\n")
                            try response.writeUTF8("Upgrade: WebSocket\r\n")
                            try response.writeUTF8("Connection: Upgrade\r\n")
                            try response.writeUTF8("Sec-WebSocket-Accept: \(acceptEncodedStr)\r\n\r\n")
                        }
                    } catch let e {
                        log("error writing handshake: \(e)")
                        return false
                    }
                    log("handshake written to socket")
                    // enter non-blocking mode
                    if !setNonBlocking() {
                        return false
                    }
                    
                    return true
                }
                log("invalid handshake - missing sec-websocket-key or sec-websocket-version")
            }
        }
        log("invalid handshake - missing or malformed \"upgrade\" header")
        return false
    }
    
    func setNonBlocking() -> Bool {
        log("setting socket to non blocking")
        let nbResult = bw_nbioify(request.fd)
        if nbResult < 0 {
            log("unable to set socket to non blocking \(nbResult)")
            return false
        }
        return true
    }
    
    func handleRead() throws {
        var buf = [UInt8](repeating: 0, count: 1)
        let n = recv(fd, &buf, 1, 0)
        if n <= 0 {
            log("nothign to read... killing socket")
            throw BRHTTPServerError.socketRecvFailed
        }
        parseMessage(buf[0])
    }

    // swiftlint:disable cyclomatic_complexity
    func parseMessage(_ byte: UInt8) {
        if state == .headerb1 {
            fin = byte & UInt8(0x80)
            guard let opc = SocketOpcode(rawValue: byte & UInt8(0x0F)) else {
                log("invalid opcode")
                return
            }
            opcode = opc
            log("parse HEADERB1 fin=\(fin) opcode=\(opcode)")
            state = .headerb2
            index = 0
            length = 0
            let rsv = byte & 0x70
            if rsv != 0 {
                // fail out here probably
                log("rsv bit is not zero! wat!")
                return
            }
        } else if state == .headerb2 {
            let mask = byte & 0x80
            let length = byte & 0x7F
            if opcode == .ping {
                log("ping packet is too large! wat!")
                return
            }
            hasMask = mask == 128
            if length <= 125 {
                self.length = Int(length)
                if hasMask {
                    maskarray = [UInt8](repeating: 0, count: 4)
                    maskarrayWritten = 0
                    state = .mask
                } else {
                    // there is no mask and no payload then we're done
                    if length <= 0 {
                        handlePacket()
                        data = [UInt8]()
                        dataWritten = 0
                        state = .headerb1
                    } else {
                        // there is no mask and some payload
                        data = [UInt8](repeating: 0, count: self.length)
                        dataWritten = 0
                        state = .payload
                    }
                }
            } else if length == 126 {
                lengtharray = [UInt8](repeating: 0, count: 2)
                lengtharrayWritten = 0
                state = .lengthshort
            } else if length == 127 {
                lengtharray = [UInt8](repeating: 0, count: 8)
                lengtharrayWritten = 0
                state = .lengthlong
            }
            log("parse HEADERB2 hasMask=\(hasMask) opcode=\(opcode)")
        } else if state == .lengthshort {
            lengtharrayWritten += 1
            if lengtharrayWritten > 2 {
                log("short length exceeded allowable size! wat!")
                return
            }
            lengtharray[lengtharrayWritten - 1] = byte
            if lengtharrayWritten == 2 {
                let ll = Data(lengtharray).withUnsafeBytes { (p: UnsafeRawBufferPointer) -> UInt16 in
                    let value = p.load(as: UInt16.self)
                    if Int(OSHostByteOrder()) != OSBigEndian {
                        return CFSwapInt16BigToHost(value)
                    }
                    return value
                }
                length = Int(ll)
                if hasMask {
                    maskarray = [UInt8](repeating: 0, count: 4)
                    maskarrayWritten = 0
                    state = .mask
                } else {
                    if length <= 0 {
                        handlePacket()
                        data = [UInt8]()
                        dataWritten = 0
                        state = .headerb1
                    } else {
                        data = [UInt8](repeating: 0, count: length)
                        dataWritten = 0
                        state = .payload
                    }
                }
            }
            log("parse LENGTHSHORT lengtharrayWritten=\(lengtharrayWritten) length=\(length) state=\(state) opcode=\(opcode)")
        } else if state == .lengthlong {
            lengtharrayWritten += 1
            if lengtharrayWritten > 8 {
                log("long length exceeded allowable size! wat!")
                return
            }
            lengtharray[lengtharrayWritten - 1] = byte
            if lengtharrayWritten == 8 {
                let ll = Data(lengtharray).withUnsafeBytes { (p: UnsafeRawBufferPointer) -> UInt64 in
                    let value = p.load(as: UInt64.self)
                    if Int(OSHostByteOrder()) != OSBigEndian {
                        return CFSwapInt64BigToHost(value)
                    }
                    return value
                }
                length = Int(ll)
                if hasMask {
                    maskarray = [UInt8](repeating: 0, count: 4)
                    maskarrayWritten = 0
                    state = .mask
                } else {
                    if length <= 0 {
                        handlePacket()
                        data = [UInt8]()
                        dataWritten = 0
                        state = .headerb1
                    } else {
                        data = [UInt8](repeating: 0, count: length)
                        dataWritten = 0
                        state = .payload
                    }
                }
            }
            log("parse LENGTHLONG lengtharrayWritten=\(lengtharrayWritten) length=\(length) state=\(state) opcode=\(opcode)")
        } else if state == .mask {
            maskarrayWritten += 1
            if lengtharrayWritten > 4 {
                log("mask exceeded allowable size! wat!")
                return
            }
            maskarray[maskarrayWritten - 1] = byte
            if maskarrayWritten == 4 {
                if length <= 0 {
                    handlePacket()
                    data = [UInt8]()
                    dataWritten = 0
                    state = .headerb1
                } else {
                    data = [UInt8](repeating: 0, count: length)
                    dataWritten = 0
                    state = .payload
                }
            }
            log("parse MASK maskarrayWritten=\(maskarrayWritten) state=\(state)")
        } else if state == .payload {
            dataWritten += 1
            if dataWritten >= MAXPAYLOAD {
                log("payload exceed allowable size! wat!")
                return
            }
            if hasMask {
                log("payload byte length=\(length) mask=\(maskarray[index%4]) byte=\(byte)")
                data[dataWritten - 1] = byte ^ maskarray[index % 4]
            } else {
                log("payload byte length=\(length) \(byte)")
                data[dataWritten - 1] = byte
            }
            if index + 1 == length {
                log("payload done")
                handlePacket()
                data = [UInt8]()
                dataWritten = 0
                state = .headerb1
            } else {
                index += 1
            }
        }
    }
    
    func handlePacket() {
        log("handle packet state=\(state) opcode=\(opcode)")
        // validate opcode
        if opcode == .close || opcode == .stream || opcode == .text || opcode == .binary {
            // valid
        } else if opcode == .pong || opcode == .ping {
            if dataWritten >  125 {
                log("control frame length can not be > 125")
                return
            }
        } else {
            log("unknown opcode")
            return
        }
        
        if opcode == .close {
            log("CLOSE")
            var status = SocketCloseEventCode.close_NORMAL
            var reason = ""
            if dataWritten >= 2 {
                let lt = Array(data.prefix(2))
                let ll = Data(lt).withUnsafeBytes { (p: UnsafeRawBufferPointer) -> UInt16 in
                    let value = p.load(as: UInt16.self)
                    return CFSwapInt16BigToHost(value)
                }
                if let ss = SocketCloseEventCode(rawValue: ll) {
                    status = ss
                } else {
                    status = .close_PROTOCOL_ERROR
                }
                let lr = Array(data.suffix(from: 2))
                if !lr.isEmpty {
                    if let rr = String(bytes: lr, encoding: String.Encoding.utf8) {
                        reason = rr
                    } else {
                        log("bad utf8 data in close reason string...")
                        status = .close_PROTOCOL_ERROR
                        reason = "bad UTF8 data"
                    }
                }
            } else {
                status = .close_PROTOCOL_ERROR
            }
            close(status, reason: reason)
        } else if fin == 0 {
            log("getting fragment \(fin)")
            if opcode != .stream {
                if opcode == .ping || opcode == .pong {
                    log("error: control messages can not be fragmented")
                    return
                }
                // start of fragments
                fragType = opcode
                fragStart = true
                fragBuffer += data
            } else {
                if !fragStart {
                    log("error: fragmentation protocol error y")
                    return
                }
                fragBuffer += data
            }
        } else {
            if opcode == .stream {
                if !fragStart {
                    log("error: fragmentation protocol error x")
                    return
                }
                if self.fragType == .text {
                    if let str = String(bytes: data, encoding: String.Encoding.utf8) {
                        self.client?.socket(self, didReceiveText: str)
                    } else {
                        log("error decoding utf8 data")
                    }
                } else {
                    let bin = Data(bytes: UnsafePointer<UInt8>(UnsafePointer(data)), count: data.count)
                    self.client?.socket(self, didReceiveData: bin)
                }
                fragType = .binary
                fragStart = false
                fragBuffer = [UInt8]()
            } else if opcode == .ping {
                sendMessage(false, opcode: .pong, data: data)
            } else if opcode == .pong {
                // nothing to do
            } else {
                if fragStart {
                    log("error: fragment protocol error z")
                    return
                }
                if opcode == .text {
                    if let str = String(bytes: data, encoding: String.Encoding.utf8) {
                        self.client?.socket(self, didReceiveText: str)
                    } else {
                        log("error decoding uft8 data")
                    }
                }
            }
        }
    }
    
    func close(_ status: SocketCloseEventCode = .close_NORMAL, reason: String = "") {
        if !closed {
            log("sending close")
            sendMessage(false, opcode: .close, data: status.rawValue.toNetwork() + [UInt8](reason.utf8))
        } else {
            log("socket is already closed")
        }
        closed = true
    }
    
    func sendMessage(_ fin: Bool, opcode: SocketOpcode, data: [UInt8]) {
        log("send message opcode=\(opcode)")
        var b1: UInt8 = 0
        var b2: UInt8 = 0
        if !fin { b1 |= 0x80 }
        var payload = [UInt8]() // todo: pick the right size for this
        b1 |= opcode.rawValue
        payload.append(b1)
        if data.count <= 125 {
            b2 |= UInt8(data.count)
            payload.append(b2)
        } else if data.count >= 126 && data.count <= 65535 {
            b2 |= 126
            payload.append(b2)
            payload.append(contentsOf: UInt16(data.count).toNetwork())
        } else {
            b2 |= 127
            payload.append(b2)
            payload.append(contentsOf: UInt64(data.count).toNetwork())
        }
        payload.append(contentsOf: data)
        sendq.append((opcode, payload))
    }
    
    func log(_ s: String) {
        print("[BRWebSocket \(fd)] \(s)")
    }
}

extension UInt16 {
    func toNetwork() -> [UInt8] {
        var selfBig = CFSwapInt16HostToBig(self)
        let size = MemoryLayout<UInt16>.size
        return Data(bytes: &selfBig, count: size).withUnsafeBytes({ (p: UnsafeRawBufferPointer) -> [UInt8] in
            return Array(p)
        })
    }
}

extension UInt64 {
    func toNetwork() -> [UInt8] {
        var selfBig = CFSwapInt64HostToBig(self)
        let size = MemoryLayout<UInt64>.size
        return Data(bytes: &selfBig, count: size).withUnsafeBytes({ (p: UnsafeRawBufferPointer) -> [UInt8] in
            return Array(p)
        })
    }
}
