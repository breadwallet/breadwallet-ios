//
//  BRTar.swift
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


enum BRTarError: Error {
    case unknown
    case fileDoesntExist
}

enum BRTarType {
    case file
    case directory
    case nullBlock
    case headerBlock
    case unsupported
    case invalid
    
    init(fromData: Data) {
        if fromData.count < 1 {
            BRTar.log("invalid data")
            self = .invalid
            return
        }
        let byte = (fromData as NSData).bytes.bindMemory(to: CChar.self, capacity: fromData.count)[0]
        switch byte {
        case CChar(48): // "0"
            self = .file
        case CChar(53): // "5"
            self = .directory
        case CChar(0):
            self = .nullBlock
        case CChar(120): // "x"
            self = .headerBlock
        case CChar(49), CChar(50), CChar(51), CChar(52), CChar(53), CChar(54), CChar(55), CChar(103):
            // "1, 2, 3, 4, 5, 6, 7, g"
            self = .unsupported
        default:
            BRTar.log("invalid block type: \(byte)")
            self = .invalid
        }
    }
}

class BRTar {
    static let tarBlockSize: UInt64 = 512
    static let tarTypePosition: UInt64 = 156
    static let tarNamePosition: UInt64 = 0
    static let tarNameSize: UInt64 = 100
    static let tarSizePosition: UInt64 = 124
    static let tarSizeSize: UInt64 = 12
    static let tarMaxBlockLoadInMemory: UInt64 = 100
    static let tarLogEnabled: Bool = false
    
    static func createFilesAndDirectoriesAtPath(_ path: String, withTarPath tarPath: String) throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: tarPath) {
            log("tar file \(tarPath) does not exist")
            throw BRTarError.fileDoesntExist
        }
        let attrs = try fm.attributesOfItem(atPath: tarPath)
        guard let tarFh = FileHandle(forReadingAtPath: tarPath) else {
            log("could not open tar file for reading")
            throw BRTarError.unknown
        }
        var loc: UInt64 = 0
        guard let sizee = attrs[FileAttributeKey.size] as? Int else {
            log("could not read tar file size")
            throw BRTarError.unknown
        }
        let size = UInt64(sizee)
        
        while loc < size {
            var blockCount: UInt64 = 1
            let tarType = readTypeAtLocation(loc, fromHandle: tarFh)
            switch tarType {
            case .file:
                // read name
                let name = try readNameAtLocation(loc, fromHandle: tarFh)
                log("got file name from tar \(name)")
                let newFilePath = (path as NSString).appendingPathComponent(name)
                log("will write to \(newFilePath)")
                var size = readSizeAtLocation(loc, fromHandle: tarFh)
                log("its size is \(size)")
                
                if fm.fileExists(atPath: newFilePath) {
                    try fm.removeItem(atPath: newFilePath)
                }
                if size == 0 {
                    // empty file
                    try "" .write(toFile: newFilePath, atomically: true, encoding: String.Encoding.utf8)
                    break
                }
                blockCount += (size - 1) / tarBlockSize + 1
                // write file
                fm.createFile(atPath: newFilePath, contents: nil, attributes: nil)
                guard let destFh = FileHandle(forWritingAtPath: newFilePath) else {
                    log("unable to open destination file for writing")
                    throw BRTarError.unknown
                }
                tarFh.seek(toFileOffset: loc + tarBlockSize)
                let maxSize = tarMaxBlockLoadInMemory * tarBlockSize
                while size > maxSize {
                    autoreleasepool(invoking: { () -> () in
                        destFh.write(tarFh.readData(ofLength: Int(maxSize)))
                        size -= maxSize
                    })
                }
                destFh.write(tarFh.readData(ofLength: Int(size)))
                destFh.closeFile()
                log("success writing file")
                break
            case .directory:
                let name = try readNameAtLocation(loc, fromHandle: tarFh)
                log("got new directory name \(name)")
                let dirPath = (path as NSString).appendingPathComponent(name)
                log("will create directory at \(dirPath)")
                
                if fm.fileExists(atPath: dirPath) {
                    try fm.removeItem(atPath: dirPath) // will automatically recursively remove directories if exists
                }
                
                try fm.createDirectory(atPath: dirPath, withIntermediateDirectories: true, attributes: nil)
                log("success creating directory")
                break
            case .nullBlock:
                break
            case .headerBlock:
                blockCount += 1
                break
            case .unsupported:
                let size = readSizeAtLocation(loc, fromHandle: tarFh)
                blockCount += size / tarBlockSize
                break
            case .invalid:
                log("Invalid block encountered")
                throw BRTarError.unknown
            }
            loc += blockCount * tarBlockSize
            log("new location \(loc)")
        }
    }
    
    static fileprivate func readTypeAtLocation(_ location: UInt64, fromHandle handle: FileHandle) -> BRTarType {
        log("reading type at location \(location)")
        handle.seek(toFileOffset: location + tarTypePosition)
        let typeDat = handle.readData(ofLength: 1)
        let ret = BRTarType(fromData: typeDat)
        log("type: \(ret)")
        return ret
    }
    
    static fileprivate func readNameAtLocation(_ location: UInt64, fromHandle handle: FileHandle) throws -> String {
        handle.seek(toFileOffset: location + tarNamePosition)
        let dat = handle.readData(ofLength: Int(tarNameSize))
        guard let ret = String(bytes: dat, encoding: String.Encoding.ascii) else {
            log("unable to read name")
            throw BRTarError.unknown
        }
        return ret
    }
    
    static fileprivate func readSizeAtLocation(_ location: UInt64, fromHandle handle: FileHandle) -> UInt64 {
        handle.seek(toFileOffset: location + tarSizePosition)
        let sizeDat = handle.readData(ofLength: Int(tarSizeSize))
        let octal = NSString(data: sizeDat, encoding: String.Encoding.ascii.rawValue)!
        log("size octal: \(octal)")
        let dec = strtoll(octal.utf8String, nil, 8)
        log("size decimal: \(dec)")
        return UInt64(dec)
    }
    
    static fileprivate func log(_ string: String) {
        if tarLogEnabled {
            print("[BRTar] \(string)")
        }
    }
}
