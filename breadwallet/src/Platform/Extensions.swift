//
//  Extensions.swift
//  BreadWallet
//
//  Created by Samuel Sutch on 1/30/16.
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
import libbz2


public extension String {
    func md5() -> String {
        guard let data = self.data(using: .utf8) else {
            #if DEBUG
                fatalError("couldnt encode string as utf8 data")
            #else
                print("couldnt encode as utf8 data")
                return
            #endif
        }
        
        var result = Data(capacity: 128/8)
        return result.withUnsafeMutableBytes { (resultBytes: UnsafeMutablePointer<CUnsignedChar>) -> String in
            data.withUnsafeBytes { (dataBytes) -> Void in
                BRMD5(resultBytes, dataBytes, data.count)
            }
            var hash = String()
            for i in 0..<result.count {
                hash = hash.appendingFormat("%02x", resultBytes[i])
            }
            return hash
        }
    }
    
    func parseQueryString() -> [String: [String]] {
        var ret = [String: [String]]()
        var strippedString = self
        if self.substring(to: self.characters.index(self.startIndex, offsetBy: 1)) == "?" {
            strippedString = self.substring(from: self.characters.index(self.startIndex, offsetBy: 1))
        }
        strippedString = strippedString.replacingOccurrences(of: "+", with: " ")
        strippedString = strippedString.removingPercentEncoding!
        for s in strippedString.components(separatedBy: "&") {
            let kp = s.components(separatedBy: "=")
            if kp.count == 2 {
                if var k = ret[kp[0]] {
                    k.append(kp[1])
                } else {
                    ret[kp[0]] = [kp[1]]
                }
            }
        }
        return ret
    }
    
    static func buildQueryString(_ options: [String: [String]]?, includeQ: Bool = false) -> String {
        var s = ""
        if let options = options , options.count > 0 {
            s = includeQ ? "?" : ""
            var i = 0
            for (k, vals) in options {
                for v in vals {
                    if i != 0 {
                        s += "&"
                    }
                    i += 1
                    s += "\(k.urlEscapedString)=\(v.urlEscapedString)"
                }
            }
        }
        return s
    }
}

var BZCompressionBufferSize: UInt32 = 1024
var BZDefaultBlockSize: Int32 = 7
var BZDefaultWorkFactor: Int32 = 100

public extension Data {
    var hexString: String {
        return reduce("") {$0 + String(format: "%02x", $1)}
    }
    
    var bzCompressedData: Data? {
        get {
            if self.count == 0 {
                return self
            }
            var compressed = [UInt8]()
            var stream = bz_stream()
            var mself = self
            var success = true
            mself.withUnsafeMutableBytes { (selfBuff: UnsafeMutablePointer<Int8>) -> Void in
                stream.next_in = selfBuff
                stream.avail_in = UInt32(self.count)
                var buff = Data(capacity: Int(BZCompressionBufferSize))
                buff.withUnsafeMutableBytes({ (outBuff: UnsafeMutablePointer<Int8>) -> Void in
                    stream.next_out = outBuff
                    stream.avail_out = BZCompressionBufferSize
                    var bzret = BZ2_bzCompressInit(&stream, BZDefaultBlockSize, 0, BZDefaultWorkFactor)
                    if bzret != BZ_OK {
                        print("failed compression init")
                        success = false
                        return
                    }
                    repeat {
                        bzret = BZ2_bzCompress(&stream, stream.avail_in > 0 ? BZ_RUN : BZ_FINISH)
                        if bzret < BZ_OK {
                            print("failed compress")
                            success = false
                            return
                        }
                        buff.withUnsafeBytes({ (bp: UnsafePointer<UInt8>) -> Void in
                            let bpp = UnsafeBufferPointer(
                                start: bp, count: (Int(BZCompressionBufferSize) - Int(stream.avail_out)))
                            compressed.append(contentsOf: bpp)
                        })
                        stream.next_out = outBuff
                        stream.avail_out = BZCompressionBufferSize
                    } while bzret != BZ_STREAM_END
                })
            }
            BZ2_bzCompressEnd(&stream)
            if !success {
                return nil
            }
            return Data(bytes: compressed)
        }
    }

    init?(bzCompressedData data: Data) {
        if data.count == 0 {
            return nil
        }
        var stream = bz_stream()
        var decompressed = [UInt8]()
        var myDat = data
        var success = true
        myDat.withUnsafeMutableBytes { (datBuff: UnsafeMutablePointer<Int8>) -> Void in
            stream.next_in = datBuff
            stream.avail_in = UInt32(data.count)
            var buff = Data(capacity: Int(BZCompressionBufferSize))
            buff.withUnsafeMutableBytes { (outBuff: UnsafeMutablePointer<Int8>) -> Void in
                stream.next_out = outBuff
                stream.avail_out = BZCompressionBufferSize
                var bzret = BZ2_bzDecompressInit(&stream, 0, 0)
                if bzret != BZ_OK {
                    print("failed decompress init")
                    success = false
                    return
                }
                repeat {
                    bzret = BZ2_bzDecompress(&stream)
                    if bzret < BZ_OK {
                        print("failed decompress")
                        success = false
                        return
                    }
                    buff.withUnsafeBytes({ (bp: UnsafePointer<UInt8>) -> Void in
                        let bpp = UnsafeBufferPointer(
                            start: bp, count: (Int(BZCompressionBufferSize) - Int(stream.avail_out)))
                        decompressed.append(contentsOf: bpp)
                    })
                    stream.next_out = outBuff
                    stream.avail_out = BZCompressionBufferSize
                } while bzret != BZ_STREAM_END
            }
        }
        BZ2_bzDecompressEnd(&stream)
        if !success {
            return nil
        }
        self.init(bytes: decompressed)
    }
    
    var base58: String {
        return self.withUnsafeBytes { (selfBytes: UnsafePointer<UInt8>) -> String in
            let len = BRBase58Encode(nil, 0, selfBytes, self.count)
            var data = Data(capacity: len)
            _ = data.withUnsafeMutableBytes {
                BRBase58Encode($0, len, selfBytes, self.count)
            }
            guard let ret = String(data: data, encoding: .utf8) else {
                #if DEBUG
                fatalError("Unable to encode base58 string")
                #else
                print("unable to encode base58 string")
                return ""
                #endif
            }
            return ret
        }
    }

    var sha1: Data {
        var data = Data(capacity: 20)
        data.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<UInt8>) in
            self.withUnsafeBytes({ (selfBytes: UnsafePointer<UInt8>) in
                BRSHA1(bytes, selfBytes, self.count)
            })
        }
        return data
    }
    
    var sha256: Data {
        var data = Data(capacity: 32)
        data.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<UInt8>) in
            self.withUnsafeBytes({ (selfBytes: UnsafePointer<UInt8>) in
                BRSHA256(bytes, selfBytes, self.count)
            })
        }
        return data
    }

    var sha256_2: Data {
        return self.sha256.sha256
    }
    
    var uInt256: UInt256 {
        return self.withUnsafeBytes { (ptr: UnsafePointer<UInt256>) -> UInt256 in
            return ptr.pointee
        }
    }
    
    public func uInt8(atOffset offset: UInt) -> UInt8 {
        let offt = Int(offset)
        let size = MemoryLayout<UInt8>.size
        if self.count < offt + size { return 0 }
        return self.subdata(in: offt..<(offt+size)).withUnsafeBytes { (ptr: UnsafePointer<UInt8>) -> UInt8 in
            return ptr.pointee
        }
    }
    
    public func uInt32(atOffset offset: UInt) -> UInt32 {
        let offt = Int(offset)
        let size = MemoryLayout<UInt32>.size
        if self.count < offt + size { return 0 }
        return self.subdata(in: offt..<(offt+size)).withUnsafeBytes { (ptr: UnsafePointer<UInt32>) -> UInt32 in
            return CFSwapInt32LittleToHost(ptr.pointee)
        }
    }
    
    public func uInt64(atOffset offset: UInt) -> UInt64 {
        let offt = Int(offset)
        let size = MemoryLayout<UInt64>.size
        if self.count < offt + size { return 0 }
        return self.subdata(in: offt..<(offt+size)).withUnsafeBytes { (ptr: UnsafePointer<UInt64>) -> UInt64 in
            return CFSwapInt64LittleToHost(ptr.pointee)
        }
    }
    
    public func compactSign(key: BRKey) -> Data {
        return self.withUnsafeBytes({ (selfBytes: UnsafePointer<UInt8>) -> Data in
            var data = Data(capacity: 65)
            var k = key
            return data.withUnsafeMutableBytes({ (bytes: UnsafeMutablePointer<UInt8>) -> Data in
                BRKeyCompactSign(&k, bytes, 65, self.uInt256)
                return data
            })
        })
    }

    fileprivate func genNonce() -> [UInt8] {
        var tv = timeval()
        gettimeofday(&tv, nil)
        var t = UInt64(tv.tv_usec) * 1_000_000 + UInt64(tv.tv_usec)
        let p = [UInt8](repeating: 0, count: 4)
        return Data(bytes: &t, count: MemoryLayout<UInt64>.size).withUnsafeBytes { (dat: UnsafePointer<UInt8>) -> [UInt8] in
            let buf = UnsafeBufferPointer(start: dat, count: MemoryLayout<UInt64>.size)
            return p + Array(buf)
        }
    }
    
    public func chacha20Poly1305AEADEncrypt(key: BRKey) -> Data {
        let data = [UInt8](self)
        let inData = UnsafePointer<UInt8>(data)
        let nonce = genNonce()
        var null =  CChar(0)
        var sk = key.secret
        return withUnsafePointer(to: &sk) {
            let outSize = BRChacha20Poly1305AEADEncrypt(nil, 0, $0, nonce, inData, data.count, &null, 0)
            var outData = [UInt8](repeating: 0, count: outSize)
            BRChacha20Poly1305AEADEncrypt(&outData, outSize, $0, nonce, inData, data.count, &null, 0)
            return Data(nonce + outData)
        }
    }
    
    public func chacha20Poly1305AEADDecrypt(key: BRKey) -> Data {
        let data = [UInt8](self)
        let nonce = Array(data[data.startIndex...data.startIndex.advanced(by: 12)])
        let inData = Array(data[data.startIndex.advanced(by: 12)...(data.endIndex-1)])
        var null =  CChar(0)
        var sk = key.secret
        return withUnsafePointer(to: &sk) {
            let outSize = BRChacha20Poly1305AEADDecrypt(nil, 0, $0, nonce, inData, inData.count, &null, 0)
            var outData = [UInt8](repeating: 0, count: outSize)
            BRChacha20Poly1305AEADDecrypt(&outData, outSize, $0, nonce, inData, inData.count, &null, 0)
            return Data(outData)
        }
    }
}

public extension Date {
    static func withMsTimestamp(_ ms: UInt64) -> Date {
        return Date(timeIntervalSince1970: Double(ms) / 1000.0)
    }
    
    func msTimestamp() -> UInt64 {
        return UInt64((self.timeIntervalSince1970 < 0 ? 0 : self.timeIntervalSince1970) * 1000.0)
    }

    // this is lifted from: https://github.com/Fykec/NSDate-RFC1123/blob/master/NSDate%2BRFC1123.swift
    // Copyright © 2015 Foster Yin. All rights reserved.
    fileprivate static func cachedThreadLocalObjectWithKey<T: AnyObject>(_ key: String, create: () -> T) -> T {
        let threadDictionary = Thread.current.threadDictionary
        if let cachedObject = threadDictionary[key] as! T? {
            return cachedObject
        }
        else {
            let newObject = create()
            threadDictionary[key] = newObject
            return newObject
        }
    }
    
    fileprivate static func RFC1123DateFormatter() -> DateFormatter {
        return cachedThreadLocalObjectWithKey("RFC1123DateFormatter") {
            let locale = Locale(identifier: "en_US")
            let timeZone = TimeZone(identifier: "GMT")
            let dateFormatter = DateFormatter()
            dateFormatter.locale = locale //need locale for some iOS 9 verision, will not select correct default locale
            dateFormatter.timeZone = timeZone
            dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
            return dateFormatter
        }
    }
    
    fileprivate static func RFC850DateFormatter() -> DateFormatter {
        return cachedThreadLocalObjectWithKey("RFC850DateFormatter") {
            let locale = Locale(identifier: "en_US")
            let timeZone = TimeZone(identifier: "GMT")
            let dateFormatter = DateFormatter()
            dateFormatter.locale = locale //need locale for some iOS 9 verision, will not select correct default locale
            dateFormatter.timeZone = timeZone
            dateFormatter.dateFormat = "EEEE, dd-MMM-yy HH:mm:ss z"
            return dateFormatter
        }
    }
    
    fileprivate static func asctimeDateFormatter() -> DateFormatter {
        return cachedThreadLocalObjectWithKey("asctimeDateFormatter") {
            let locale = Locale(identifier: "en_US")
            let timeZone = TimeZone(identifier: "GMT")
            let dateFormatter = DateFormatter()
            dateFormatter.locale = locale //need locale for some iOS 9 verision, will not select correct default locale
            dateFormatter.timeZone = timeZone
            dateFormatter.dateFormat = "EEE MMM d HH:mm:ss yyyy"
            return dateFormatter
        }
    }
    
    static func fromRFC1123(_ dateString: String) -> Date? {
        
        var date: Date?
        // RFC1123
        date = Date.RFC1123DateFormatter().date(from: dateString)
        if date != nil {
            return date
        }
        
        // RFC850
        date = Date.RFC850DateFormatter().date(from: dateString)
        if date != nil {
            return date
        }
        
        // asctime-date
        date = Date.asctimeDateFormatter().date(from: dateString)
        if date != nil {
            return date
        }
        return nil
    }
    
    func RFC1123String() -> String? {
        return Date.RFC1123DateFormatter().string(from: self)
    }
}

public extension BRKey {
    public var publicKey: Data {
        var k = self
        return withUnsafeMutablePointer(to: &k) { pk in
            let len = BRKeyPubKey(pk, nil, 0)
            var data = Data(capacity: len)
            return data.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<UInt8>) -> Data in
                BRKeyPubKey(pk, bytes, len)
                return data
            }
        }
    }
}
