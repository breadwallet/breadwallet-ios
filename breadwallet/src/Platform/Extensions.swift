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
import UIKit

public extension String {
    static func buildQueryString(_ options: [String: [String]]?, includeQ: Bool = false) -> String {
        var s = ""
        if let options = options, !options.isEmpty {
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
    
    static var urlQuoteCharacterSet: CharacterSet {
        if let cset = (NSMutableCharacterSet.urlQueryAllowed as NSCharacterSet).mutableCopy() as? NSMutableCharacterSet {
            cset.removeCharacters(in: "?=&")
            return cset as CharacterSet
        }
        return NSMutableCharacterSet.urlQueryAllowed as CharacterSet
    }
    
    func md5() -> String {
        guard let stringData = self.data(using: .utf8) else {
            assert(false, "couldnt encode string as utf8 data")
            return ""
        }
        
        var data = [UInt8](stringData)
        var result = [UInt8](repeating: 0, count: 128/8)
        let resultCount = result.count
        BRMD5(&result, &data, data.count)
        var hash = String()
        for i in 0..<resultCount {
            hash = hash.appendingFormat("%02x", result[i])
        }
        return hash
    }
    
    func base58DecodedData() -> Data {
        let len = BRBase58Decode(nil, 0, self)
        var data = [UInt8](repeating: 0, count: len)
        BRBase58Decode(&data, len, self)
        return Data(data)
    }
    
    var urlEscapedString: String {
        return addingPercentEncoding(withAllowedCharacters: String.urlQuoteCharacterSet) ?? ""
    }
    
    func parseQueryString() -> [String: [String]] {
        var ret = [String: [String]]()
        var strippedString = self
        if String(self[..<self.index(self.startIndex, offsetBy: 1)]) == "?" {
            strippedString = String(self[self.index(self.startIndex, offsetBy: 1)...])
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
}

extension UserDefaults {
    var deviceID: String {
        if let s = string(forKey: "BR_DEVICE_ID") {
            return s
        }
        let s = CFUUIDCreateString(nil, CFUUIDCreate(nil)) as String
        setValue(s, forKey: "BR_DEVICE_ID")
        print("new device id \(s)")
        return s
    }
}

let VAR_INT16_HEADER: UInt64 = 0xfd
let VAR_INT32_HEADER: UInt64 = 0xfe
let VAR_INT64_HEADER: UInt64 = 0xff

extension NSMutableData {

    func appendVarInt(i: UInt64) {
        if i < VAR_INT16_HEADER {
            var payload = UInt8(i)
            append(&payload, length: MemoryLayout<UInt8>.size)
        } else if Int32(i) <= UINT16_MAX {
            var header = UInt8(VAR_INT16_HEADER)
            var payload = CFSwapInt16HostToLittle(UInt16(i))
            append(&header, length: MemoryLayout<UInt8>.size)
            append(&payload, length: MemoryLayout<UInt16>.size)
        } else if UInt32(i) <= UINT32_MAX {
            var header = UInt8(VAR_INT32_HEADER)
            var payload = CFSwapInt32HostToLittle(UInt32(i))
            append(&header, length: MemoryLayout<UInt8>.size)
            append(&payload, length: MemoryLayout<UInt32>.size)
        } else {
            var header = UInt8(VAR_INT64_HEADER)
            var payload = CFSwapInt64HostToLittle(i)
            append(&header, length: MemoryLayout<UInt8>.size)
            append(&payload, length: MemoryLayout<UInt64>.size)
        }
    }
}

var BZCompressionBufferSize: UInt32 = 1024
var BZDefaultBlockSize: Int32 = 7
var BZDefaultWorkFactor: Int32 = 100

private struct AssociatedKeys {
    static var hexString = "hexString"
}

public extension Data {
    var hexString: String {
        if let string = getCachedHexString() {
            return string
        } else {
            let string = reduce("") {$0 + String(format: "%02x", $1)}
            setHexString(string: string)
            return string
        }
    }

    private func setHexString(string: String) {
        objc_setAssociatedObject(self, &AssociatedKeys.hexString, string, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    private func getCachedHexString() -> String? {
        return objc_getAssociatedObject(self, &AssociatedKeys.hexString) as? String
    }

    var bzCompressedData: Data? {
        guard !self.isEmpty else {
            return self
        }

        var compressed = Data()
        var stream = bz_stream()
        var mself = self
        var success = true
        mself.withUnsafeMutableBytes { (selfBuff: UnsafeMutableRawBufferPointer) -> Void in
            let outBuff = UnsafeMutablePointer<Int8>.allocate(capacity: Int(BZCompressionBufferSize))
            defer { outBuff.deallocate() }

            stream.next_in = selfBuff.baseAddress?.assumingMemoryBound(to: Int8.self)
            stream.avail_in = UInt32(self.count)
            stream.next_out = outBuff
            stream.avail_out = BZCompressionBufferSize

            var bzret = BZ2_bzCompressInit(&stream, BZDefaultBlockSize, 0, BZDefaultWorkFactor)
            guard bzret == BZ_OK else {
                print("failed compression init")
                success = false
                return
            }
            repeat {
                bzret = BZ2_bzCompress(&stream, stream.avail_in > 0 ? BZ_RUN : BZ_FINISH)
                guard bzret >= BZ_OK else {
                    print("failed compress")
                    success = false
                    return
                }
                let bpp = UnsafeBufferPointer(start: outBuff, count: (Int(BZCompressionBufferSize) - Int(stream.avail_out)))
                compressed.append(bpp)
                stream.next_out = outBuff
                stream.avail_out = BZCompressionBufferSize
            } while bzret != BZ_STREAM_END
        }
        BZ2_bzCompressEnd(&stream)
        guard success else { return nil }
        return compressed
    }

    init?(bzCompressedData data: Data) {
        guard !data.isEmpty else {
            return nil
        }
        var stream = bz_stream()
        var decompressed = Data()
        var myDat = data
        var success = true
        myDat.withUnsafeMutableBytes { (datBuff: UnsafeMutableRawBufferPointer) -> Void in
            let outBuff = UnsafeMutablePointer<Int8>.allocate(capacity: Int(BZCompressionBufferSize))
            defer { outBuff.deallocate() }
            
            stream.next_in = datBuff.baseAddress?.assumingMemoryBound(to: Int8.self)
            stream.avail_in = UInt32(data.count)
            stream.next_out = outBuff
            stream.avail_out = BZCompressionBufferSize
            
            var bzret = BZ2_bzDecompressInit(&stream, 0, 0)
            guard bzret == BZ_OK else {
                print("failed decompress init")
                success = false
                return
            }
            repeat {
                bzret = BZ2_bzDecompress(&stream)
                guard bzret >= BZ_OK else {
                    print("failed decompress")
                    success = false
                    return
                }
                let bpp = UnsafeBufferPointer(start: outBuff, count: (Int(BZCompressionBufferSize) - Int(stream.avail_out)))
                decompressed.append(bpp)
                stream.next_out = outBuff
                stream.avail_out = BZCompressionBufferSize
            } while bzret != BZ_STREAM_END
        }
        BZ2_bzDecompressEnd(&stream)
        guard success else { return nil }
        self.init(decompressed)
    }
    
    var base58: String {
        return self.withUnsafeBytes {
            let bytes = $0.baseAddress?.assumingMemoryBound(to: UInt8.self)
            let len = BRBase58Encode(nil, 0, bytes, self.count)
            var data = Data(count: len)
            return data.withUnsafeMutableBytes {
                guard let outBuf = $0.baseAddress?.assumingMemoryBound(to: Int8.self) else { assertionFailure(); return "" }
                BRBase58Encode(outBuf, len, bytes, self.count)
                return String(cString: outBuf)
            }
        }
    }

    var sha1: Data {
        var result = [UInt8](repeating: 0, count: 20)
        var myself = [UInt8](self)
        BRSHA1(&result, &myself, self.count)
        return Data(result)
    }
    
    var sha256: Data {
        var result = [UInt8](repeating: 0, count: 32)
        var myself = [UInt8](self)
        BRSHA256(&result, &myself, count)
        return Data(result)
    }

    var sha256_2: Data {
        return self.sha256.sha256
    }
    
    var uInt256: UInt256 {
        return self.withUnsafeBytes {
            return $0.load(as: UInt256.self)
        }
    }
    
    func uInt8(atOffset offset: UInt) -> UInt8 {
        let offt = Int(offset)
        let size = MemoryLayout<UInt8>.size
        if self.count < offt + size { return 0 }
        return self.subdata(in: offt..<(offt+size)).withUnsafeBytes {
            return $0.load(as: UInt8.self)
        }
    }
    
    func uInt32(atOffset offset: UInt) -> UInt32 {
        let offt = Int(offset)
        let size = MemoryLayout<UInt32>.size
        if self.count < offt + size { return 0 }
        return self.subdata(in: offt..<(offt+size)).withUnsafeBytes {
            return CFSwapInt32LittleToHost($0.load(as: UInt32.self))
        }
    }
    
    func uInt64(atOffset offset: UInt) -> UInt64 {
        let offt = Int(offset)
        let size = MemoryLayout<UInt64>.size
        if self.count < offt + size { return 0 }
        return self.subdata(in: offt..<(offt+size)).withUnsafeBytes {
            return CFSwapInt64LittleToHost($0.load(as: UInt64.self))
        }
    }

    func compactSign(key: BRKey) -> Data {
        var result = [UInt8](repeating: 0, count: 65)
        var k = key
        BRKeyCompactSign(&k, &result, 65, self.uInt256)
        return Data(result)
    }

    fileprivate func genNonce() -> [UInt8] {
        var tv = timeval()
        gettimeofday(&tv, nil)
        var t = UInt64(tv.tv_usec) * 1_000_000 + UInt64(tv.tv_usec)
        let p = [UInt8](repeating: 0, count: 4)
        return Data(bytes: &t, count: MemoryLayout<UInt64>.size).withUnsafeBytes {
            return p + Array($0)
        }
    }
    
    func chacha20Poly1305AEADEncrypt(key: BRKey) -> Data {
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
    
    func chacha20Poly1305AEADDecrypt(key: BRKey) throws -> Data {
        let data = [UInt8](self)
        guard data.count > 12 else { throw BRReplicatedKVStoreError.malformedData }
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

    var masterPubKey: BRMasterPubKey? {
        typealias PubKeyType = (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                                UInt8, UInt8, UInt8) //uint8_t pubKey[33];
        guard self.count >= (4 + 32 + 33) else { return nil }
        var mpk = BRMasterPubKey()
        mpk.fingerPrint = self.subdata(in: 0..<4).withUnsafeBytes { $0.load(as: UInt32.self) }
        mpk.chainCode = self.subdata(in: 4..<(4 + 32)).withUnsafeBytes { $0.load(as: UInt256.self) }
        mpk.pubKey = self.subdata(in: (4 + 32)..<(4 + 32 + 33)).withUnsafeBytes { $0.load(as: PubKeyType.self) }
        return mpk
    }

    init(masterPubKey mpk: BRMasterPubKey) {
        var data = [mpk.fingerPrint].withUnsafeBufferPointer { Data(buffer: $0) }
        [mpk.chainCode].withUnsafeBufferPointer { data.append($0) }
        [mpk.pubKey].withUnsafeBufferPointer { data.append($0) }
        self.init(data)
    }

    var urlEncodedObject: [String: [String]]? {
        guard let str = String(data: self, encoding: .utf8) else {
            return nil
        }
        return str.parseQueryString()
    }
    
    var base32: String {
        return Base32.encode(self)
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
        if let cachedObject = threadDictionary[key] as? T {
            return cachedObject
        } else {
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

extension UIImage {
    
    /// Represents a scaling mode
    enum ScalingMode {
        case aspectFill
        case aspectFit
        
        /// Calculates the aspect ratio between two sizes
        ///
        /// - parameters:
        ///     - size:      the first size used to calculate the ratio
        ///     - otherSize: the second size used to calculate the ratio
        ///
        /// - return: the aspect ratio between the two sizes
        func aspectRatio(between size: CGSize, and otherSize: CGSize) -> CGFloat {
            let aspectWidth  = size.width/otherSize.width
            let aspectHeight = size.height/otherSize.height
            
            switch self {
            case .aspectFill:
                return max(aspectWidth, aspectHeight)
            case .aspectFit:
                return min(aspectWidth, aspectHeight)
            }
        }
    }
    
    /// Scales an image to fit within a bounds with a size governed by the passed size. Also keeps the aspect ratio.
    ///
    /// - parameters:
    ///     - newSize:     the size of the bounds the image must fit within.
    ///     - scalingMode: the desired scaling mode
    ///
    /// - returns: a new scaled image.
    func scaled(to newSize: CGSize, scalingMode: UIImage.ScalingMode = .aspectFill) -> UIImage {
        
        let aspectRatio = scalingMode.aspectRatio(between: newSize, and: size)
        
        /* Build the rectangle representing the area to be drawn */
        var scaledImageRect = CGRect.zero
        
        scaledImageRect.size.width  = size.width * aspectRatio
        scaledImageRect.size.height = size.height * aspectRatio
        scaledImageRect.origin.x    = (newSize.width - size.width * aspectRatio) / 2.0
        scaledImageRect.origin.y    = (newSize.height - size.height * aspectRatio) / 2.0
        
        /* Draw and retrieve the scaled image */
        UIGraphicsBeginImageContext(newSize)
        
        draw(in: scaledImageRect)
        let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
        
        UIGraphicsEndImageContext()
        
        return scaledImage!
    }
}

extension Dictionary where Key: ExpressibleByStringLiteral, Value: Any {
    var flattened: [Key: String] {
        var ret = [Key: String]()
        for (k, v) in self {
            if let v = v as? [String], !v.isEmpty {
                ret[k] = v[0]
            }
        }
        return ret
    }
    
    var jsonString: String {
        guard let json = try? JSONSerialization.data(withJSONObject: self, options: []) else {
            return "null"
        }
        guard let jstring = String(data: json, encoding: .utf8) else {
            return "null"
        }
        return jstring
    }
}

extension Array {
    func chunked(by chunkSize: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: chunkSize).map {
            Array(self[$0..<Swift.min($0 + chunkSize, count)])
        }
    }
}

extension Result where Success == Void {
    static var success: Result {
        return .success(())
    }
}

//  Bases32 Encoding provided by:
//  https://github.com/mattrubin/Bases
//  Commit: 6b780caed18179a598ba574ce12e75674d6f4f1f
//
//  Copyright (c) 2015-2016 Matt Rubin and the Bases authors
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

typealias Byte = UInt8
typealias Quintet = UInt8
typealias EncodedChar = UInt8

func quintetsFromBytes(_ firstByte: Byte, _ secondByte: Byte, _ thirdByte: Byte, _ fourthByte: Byte, _ fifthByte: Byte)
    -> (Quintet, Quintet, Quintet, Quintet, Quintet, Quintet, Quintet, Quintet) {
    return (
        firstQuintet(firstByte: firstByte),
        secondQuintet(firstByte: firstByte, secondByte: secondByte),
        thirdQuintet(secondByte: secondByte),
        fourthQuintet(secondByte: secondByte, thirdByte: thirdByte),
        fifthQuintet(thirdByte: thirdByte, fourthByte: fourthByte),
        sixthQuintet(fourthByte: fourthByte),
        seventhQuintet(fourthByte: fourthByte, fifthByte: fifthByte),
        eighthQuintet(fifthByte: fifthByte)
    )
}

func quintetsFromBytes(_ firstByte: Byte, _ secondByte: Byte, _ thirdByte: Byte, _ fourthByte: Byte)
    -> (Quintet, Quintet, Quintet, Quintet, Quintet, Quintet, Quintet) {
    return (
        firstQuintet(firstByte: firstByte),
        secondQuintet(firstByte: firstByte, secondByte: secondByte),
        thirdQuintet(secondByte: secondByte),
        fourthQuintet(secondByte: secondByte, thirdByte: thirdByte),
        fifthQuintet(thirdByte: thirdByte, fourthByte: fourthByte),
        sixthQuintet(fourthByte: fourthByte),
        seventhQuintet(fourthByte: fourthByte, fifthByte: 0)
    )
}

func quintetsFromBytes(_ firstByte: Byte, _ secondByte: Byte, _ thirdByte: Byte)
    -> (Quintet, Quintet, Quintet, Quintet, Quintet) {
    return (
        firstQuintet(firstByte: firstByte),
        secondQuintet(firstByte: firstByte, secondByte: secondByte),
        thirdQuintet(secondByte: secondByte),
        fourthQuintet(secondByte: secondByte, thirdByte: thirdByte),
        fifthQuintet(thirdByte: thirdByte, fourthByte: 0)
    )
}

func quintetsFromBytes(_ firstByte: Byte, _ secondByte: Byte)
    -> (Quintet, Quintet, Quintet, Quintet) {
    return (
        firstQuintet(firstByte: firstByte),
        secondQuintet(firstByte: firstByte, secondByte: secondByte),
        thirdQuintet(secondByte: secondByte),
        fourthQuintet(secondByte: secondByte, thirdByte: 0)
    )
}

func quintetsFromBytes(_ firstByte: Byte)
    -> (Quintet, Quintet) {
    return (
        firstQuintet(firstByte: firstByte),
        secondQuintet(firstByte: firstByte, secondByte: 0)
    )
}

private func firstQuintet(firstByte: Byte) -> Quintet {
    return ((firstByte & 0b11111000) >> 3)
}

private func secondQuintet(firstByte: Byte, secondByte: Byte) -> Quintet {
    return ((firstByte & 0b00000111) << 2)
        | ((secondByte & 0b11000000) >> 6)
}

private func thirdQuintet(secondByte: Byte) -> Quintet {
    return ((secondByte & 0b00111110) >> 1)
}

private func fourthQuintet(secondByte: Byte, thirdByte: Byte) -> Quintet {
    return ((secondByte & 0b00000001) << 4)
        | ((thirdByte & 0b11110000) >> 4)
}

private func fifthQuintet(thirdByte: Byte, fourthByte: Byte) -> Quintet {
    return ((thirdByte & 0b00001111) << 1)
        | ((fourthByte & 0b10000000) >> 7)
}

private func sixthQuintet(fourthByte: Byte) -> Quintet {
    return ((fourthByte & 0b01111100) >> 2)
}

private func seventhQuintet(fourthByte: Byte, fifthByte: Byte) -> Quintet {
    return ((fourthByte & 0b00000011) << 3)
        | ((fifthByte & 0b11100000) >> 5)
}

private func eighthQuintet(fifthByte: Byte) -> Quintet {
    return (fifthByte & 0b00011111)
}

internal let paddingCharacter: EncodedChar = 61
private let encodingTable: [EncodedChar] = [65, 66, 67, 68, 69, 70, 71, 72,
                                            73, 74, 75, 76, 77, 78, 79, 80,
                                            81, 82, 83, 84, 85, 86, 87, 88,
                                            89, 90, 50, 51, 52, 53, 54, 55]

internal func character(encoding quintet: Quintet) -> EncodedChar {
    return encodingTable[Int(quintet)]
}

internal typealias EncodedBlock = (EncodedChar, EncodedChar, EncodedChar, EncodedChar, EncodedChar,
    EncodedChar, EncodedChar, EncodedChar)

internal func encodeBlock(bytes: UnsafePointer<Byte>, size: Int) -> EncodedBlock {
    switch size {
    case 1:
        return encodeBlock(bytes[0])
    case 2:
        return encodeBlock(bytes[0], bytes[1])
    case 3:
        return encodeBlock(bytes[0], bytes[1], bytes[2])
    case 4:
        return encodeBlock(bytes[0], bytes[1], bytes[2], bytes[3])
    case 5:
        return encodeBlock(bytes[0], bytes[1], bytes[2], bytes[3], bytes[4])
    default:
        fatalError()
    }
}

private func encodeBlock(_ b0: Byte, _ b1: Byte, _ b2: Byte, _ b3: Byte, _ b4: Byte) -> EncodedBlock {
    let q = quintetsFromBytes(b0, b1, b2, b3, b4)
    let c0 = character(encoding: q.0)
    let c1 = character(encoding: q.1)
    let c2 = character(encoding: q.2)
    let c3 = character(encoding: q.3)
    let c4 = character(encoding: q.4)
    let c5 = character(encoding: q.5)
    let c6 = character(encoding: q.6)
    let c7 = character(encoding: q.7)
    return (c0, c1, c2, c3, c4, c5, c6, c7)
}

private func encodeBlock(_ b0: Byte, _ b1: Byte, _ b2: Byte, _ b3: Byte) -> EncodedBlock {
    let q = quintetsFromBytes(b0, b1, b2, b3)
    let c0 = character(encoding: q.0)
    let c1 = character(encoding: q.1)
    let c2 = character(encoding: q.2)
    let c3 = character(encoding: q.3)
    let c4 = character(encoding: q.4)
    let c5 = character(encoding: q.5)
    let c6 = character(encoding: q.6)
    let c7 = paddingCharacter
    return (c0, c1, c2, c3, c4, c5, c6, c7)
}

private func encodeBlock(_ b0: Byte, _ b1: Byte, _ b2: Byte) -> EncodedBlock {
    let q = quintetsFromBytes(b0, b1, b2)
    let c0 = character(encoding: q.0)
    let c1 = character(encoding: q.1)
    let c2 = character(encoding: q.2)
    let c3 = character(encoding: q.3)
    let c4 = character(encoding: q.4)
    let c5 = paddingCharacter
    let c6 = paddingCharacter
    let c7 = paddingCharacter
    return (c0, c1, c2, c3, c4, c5, c6, c7)
}

private func encodeBlock(_ b0: Byte, _ b1: Byte) -> EncodedBlock {
    let q = quintetsFromBytes(b0, b1)
    let c0 = character(encoding: q.0)
    let c1 = character(encoding: q.1)
    let c2 = character(encoding: q.2)
    let c3 = character(encoding: q.3)
    let c4 = paddingCharacter
    let c5 = paddingCharacter
    let c6 = paddingCharacter
    let c7 = paddingCharacter
    return (c0, c1, c2, c3, c4, c5, c6, c7)
}

private func encodeBlock(_ b0: Byte) -> EncodedBlock {
    let q = quintetsFromBytes(b0)
    let c0 = character(encoding: q.0)
    let c1 = character(encoding: q.1)
    let c2 = paddingCharacter
    let c3 = paddingCharacter
    let c4 = paddingCharacter
    let c5 = paddingCharacter
    let c6 = paddingCharacter
    let c7 = paddingCharacter
    return (c0, c1, c2, c3, c4, c5, c6, c7)
}

public enum Base32 {
    /// The size of a block before encoding, measured in bytes.
    private static let unencodedBlockSize = 5
    /// The size of a block after encoding, measured in bytes.
    private static let encodedBlockSize = 8
    
    public static func encode(_ data: Data) -> String {
        let unencodedByteCount = data.count
        
        let encodedByteCount = byteCount(encoding: unencodedByteCount)
        let encodedBytes = UnsafeMutablePointer<EncodedChar>.allocate(capacity: encodedByteCount)
        
        data.withUnsafeBytes {
            guard let unencodedBytes = $0.baseAddress?.assumingMemoryBound(to: Byte.self) else { return }
            var encodedWriteOffset = 0
            for unencodedReadOffset in stride(from: 0, to: unencodedByteCount, by: unencodedBlockSize) {
                let nextBlockBytes = unencodedBytes + unencodedReadOffset
                let nextBlockSize = min(unencodedBlockSize, unencodedByteCount - unencodedReadOffset)
                
                let nextChars = encodeBlock(bytes: nextBlockBytes, size: nextBlockSize)
                encodedBytes[encodedWriteOffset + 0] = nextChars.0
                encodedBytes[encodedWriteOffset + 1] = nextChars.1
                encodedBytes[encodedWriteOffset + 2] = nextChars.2
                encodedBytes[encodedWriteOffset + 3] = nextChars.3
                encodedBytes[encodedWriteOffset + 4] = nextChars.4
                encodedBytes[encodedWriteOffset + 5] = nextChars.5
                encodedBytes[encodedWriteOffset + 6] = nextChars.6
                encodedBytes[encodedWriteOffset + 7] = nextChars.7
                
                encodedWriteOffset += encodedBlockSize
            }
        }
        
        // The Data instance takes ownership of the allocated bytes and will handle deallocation.
        let encodedData = Data(bytesNoCopy: encodedBytes,
                               count: encodedByteCount,
                               deallocator: .free)
        return String(data: encodedData, encoding: .ascii)!
    }
    
    private static func byteCount(encoding unencodedByteCount: Int) -> Int {
        let fullBlockCount = unencodedByteCount / unencodedBlockSize
        let remainingRawBytes = unencodedByteCount % unencodedBlockSize
        let blockCount = remainingRawBytes > 0 ? fullBlockCount + 1 : fullBlockCount
        return blockCount * encodedBlockSize
    }
}
