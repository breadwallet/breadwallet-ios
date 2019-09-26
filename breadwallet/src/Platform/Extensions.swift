//
//  Extensions.swift
//  BreadWallet
//
//  Created by Samuel Sutch on 1/30/16.
//  Copyright (c) 2016-2019 Breadwinner AG. All rights reserved.
//

import Foundation
import libbz2
import UIKit
import BRCrypto

// MARK: -

extension String {
    func md5() -> String {
        guard let stringData = self.data(using: .utf8) else {
            assert(false, "couldnt encode string as utf8 data")
            return ""
        }
        return CoreHasher.md5.hash(data: stringData)?.hexString ?? ""
    }
    
    func base58DecodedData() -> Data? {
        return CoreCoder.base58.decode(string: self)
    }
}

// MARK: -

private let VAR_INT16_HEADER: UInt64 = 0xfd
private let VAR_INT32_HEADER: UInt64 = 0xfe
private let VAR_INT64_HEADER: UInt64 = 0xff

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

private var BZCompressionBufferSize: UInt32 = 1024
private var BZDefaultBlockSize: Int32 = 7
private var BZDefaultWorkFactor: Int32 = 100

public extension Data {
    
    // MARK: Hex Conversion
    
    var hexString: String {
        return CoreCoder.hex.encode(data: self) ?? ""
    }

    /// Create Data with bytes from a hex string
    ///
    /// - Parameters:
    ///   - hexString: input
    ///   - reversed: reverse the bytes (for UInt256 little-endian compatibility)
    init?(hexString: String, reversed: Bool = false) {
        guard hexString.isValidHexString,
            let result = CoreCoder.hex.decode(string: hexString.withoutHexPrefix) else { return nil }
        self = reversed ? Data(result.reversed()) : result
    }
    
    // MARL: Compression

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
    
    // MARK: Encode/Decode
    
    var urlEncodedObject: [String: [String]]? {
        guard let str = String(data: self, encoding: .utf8) else {
            return nil
        }
        return str.parseQueryString()
    }
    
    var base58: String {
        return CoreCoder.base58.encode(data: self) ?? ""
    }
    
    var base32: String {
        return Base32.encode(self)
    }

    // https://tools.ietf.org/html/rfc4648#section-5
    var base64url: String {
        var result = self.base64EncodedString()
        result = result.replacingOccurrences(of: "+", with: "-")
        result = result.replacingOccurrences(of: "/", with: "_")
        result = result.replacingOccurrences(of: "=", with: "")
        return result
    }

    var sha1: Data {
        return CoreHasher.sha1.hash(data: self) ?? Data()
    }
    
    var sha256: Data {
        return CoreHasher.sha256.hash(data: self) ?? Data()
    }

    var sha256_2: Data {
        return CoreHasher.sha256_2.hash(data: self) ?? Data()
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
    
    // MARK: Sign / Encrypt

    /// Returns the signature by signing `self` with `key`, using secp256k1_ecdsa_sign_recoverable
    func compactSign(key: Key) -> Data? {
        return CoreSigner.compact.sign(data32: self, using: key)
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
    
    func chacha20Poly1305AEADEncrypt(key: Key) -> Data {
        let nonce = genNonce()
        guard key.hasSecret else { assertionFailure(); return Data() }
        let encrypter = CoreCipher.chacha20_poly1305(key: key, nonce12: Data(nonce), ad: Data())
        guard let outData = encrypter.encrypt(data: self) else { assertionFailure(); return Data() }
        return Data(nonce + outData)
    }
    
    func chacha20Poly1305AEADDecrypt(key: Key) throws -> Data {
        guard key.hasSecret else { throw BRReplicatedKVStoreError.invalidKey }
        let data = [UInt8](self)
        guard data.count > 12 else { throw BRReplicatedKVStoreError.malformedData }
        let nonce = Array(data[data.startIndex..<data.startIndex.advanced(by: 12)])
        let inData = Array(data[data.startIndex.advanced(by: 12)..<data.endIndex])
        let decrypter = CoreCipher.chacha20_poly1305(key: key, nonce12: Data(nonce), ad: Data())
        guard let decrypted = decrypter.decrypt(data: Data(inData)) else { /*assertionFailure();*/ throw BRReplicatedKVStoreError.malformedData }
        return decrypted
    }
}

// MARK: -

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

extension DateFormatter {
    static let iso8601Full: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}

// MARK: -

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

// MARK: - 

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
