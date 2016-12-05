//
//  BRBSPatch.swift
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


enum BRBSPatchError: Error {
    case unknown
    case corruptPatch
    case patchFileDoesntExist
    case oldFileDoesntExist
}


class BRBSPatch {
    static let patchLogEnabled = true
    
    static func patch(_ oldFilePath: String, newFilePath: String, patchFilePath: String)
                      throws -> UnsafeMutablePointer<CUnsignedChar> {
        func offtin(_ b: UnsafePointer<CUnsignedChar>) -> off_t {
            var y = off_t(b[0])
            y |= off_t(b[1]) << 8
            y |= off_t(b[2]) << 16
            y |= off_t(b[3]) << 24
            y |= off_t(b[4]) << 32
            y |= off_t(b[5]) << 40
            y |= off_t(b[6]) << 48
            y |= off_t(b[7] & 0x7f) << 56
            if Int(b[7]) & 0x80 != 0 {
                y = -y
            }
            return y
        }
        let patchFilePathBytes = UnsafePointer<Int8>((patchFilePath as NSString).utf8String)
        let r = UnsafePointer<Int8>(("r" as NSString).utf8String)
        
        // open patch file
        guard let f = FileHandle(forReadingAtPath: patchFilePath) else {
            log("unable to open file for reading at path \(patchFilePath)")
            throw BRBSPatchError.patchFileDoesntExist
        }
        
        // read header
        let headerData = f.readData(ofLength: 32)
        let header = (headerData as NSData).bytes.bindMemory(to: CUnsignedChar.self, capacity: headerData.count)
        if headerData.count != 32 {
            log("incorrect header read length \(headerData.count)")
            throw BRBSPatchError.corruptPatch
        }
        
        // check for appropriate magic
        let magicData = headerData.subdata(in: 0..<8)
        if let magic = String(bytes: magicData, encoding: String.Encoding.ascii), magic != "BSDIFF40" {
            log("incorrect magic: \(magic)")
            throw BRBSPatchError.corruptPatch
        }
        
        // read lengths from header
        let bzCrtlLen = offtin(header + 8)
        let bzDataLen = offtin(header + 16)
        let newSize = offtin(header + 24)
        
        if bzCrtlLen < 0 || bzDataLen < 0 || newSize < 0 {
            log("incorrect header data: crtlLen: \(bzCrtlLen) dataLen: \(bzDataLen) newSize: \(newSize)")
            throw BRBSPatchError.corruptPatch
        }
        
        // close patch file and re-open it with bzip2 at the right positions
        f.closeFile()
        
        let cpf = fopen(patchFilePathBytes, r)
        if cpf == nil {
            let s = String(cString: strerror(errno))
            let ff = String(cString: patchFilePathBytes!)
            log("unable to open patch file c: \(s) \(ff)")
            throw BRBSPatchError.unknown
        }
        let cpfseek = fseeko(cpf, 32, SEEK_SET)
        if cpfseek != 0 {
            log("unable to seek patch file c: \(cpfseek)")
            throw BRBSPatchError.unknown
        }
        let cbz2err = UnsafeMutablePointer<Int32>.allocate(capacity: 1)
        let cpfbz2 = BZ2_bzReadOpen(cbz2err, cpf, 0, 0, nil, 0)
        if cpfbz2 == nil {
            log("unable to bzopen patch file c: \(cbz2err)")
            throw BRBSPatchError.unknown
        }
        let dpf = fopen(patchFilePathBytes, r)
        if dpf == nil {
            log("unable to open patch file d")
            throw BRBSPatchError.unknown
        }
        let dpfseek = fseeko(dpf, 32 + bzCrtlLen, SEEK_SET)
        if dpfseek != 0 {
            log("unable to seek patch file d: \(dpfseek)")
            throw BRBSPatchError.unknown
        }
        let dbz2err = UnsafeMutablePointer<Int32>.allocate(capacity: 1)
        let dpfbz2 = BZ2_bzReadOpen(dbz2err, dpf, 0, 0, nil, 0)
        if dpfbz2 == nil {
            log("unable to bzopen patch file d: \(dbz2err)")
            throw BRBSPatchError.unknown
        }
        let epf = fopen(patchFilePathBytes, r)
        if epf == nil {
            log("unable to open patch file e")
            throw BRBSPatchError.unknown
        }
        let epfseek = fseeko(epf, 32 + bzCrtlLen + bzDataLen, SEEK_SET)
        if epfseek != 0 {
            log("unable to seek patch file e: \(epfseek)")
            throw BRBSPatchError.unknown
        }
        let ebz2err = UnsafeMutablePointer<Int32>.allocate(capacity: 1)
        let epfbz2 = BZ2_bzReadOpen(ebz2err, epf, 0, 0, nil, 0)
        if epfbz2 == nil {
            log("unable to bzopen patch file e: \(ebz2err)")
            throw BRBSPatchError.unknown
        }
        
        guard let oldData = try? Data(contentsOf: URL(fileURLWithPath: oldFilePath)) else {
            log("unable to read old file path")
            throw BRBSPatchError.unknown
        }
        let old = (oldData as NSData).bytes.bindMemory(to: CUnsignedChar.self, capacity: oldData.count)
        let oldSize = off_t(oldData.count)
        var oldPos: off_t = 0, newPos: off_t = 0
        let new = UnsafeMutablePointer<CUnsignedChar>.allocate(capacity: Int(newSize) + 1)
        let buf = UnsafeMutablePointer<CUnsignedChar>.allocate(capacity: 8)
        var crtl = Array<off_t>(repeating: 0, count: 3)
        while newPos < newSize {
            // read control data
            for i in 0...2 {
                let lenread = BZ2_bzRead(cbz2err, cpfbz2, buf, 8)
                if (lenread < 8) || ((cbz2err.pointee != BZ_OK) && (cbz2err.pointee != BZ_STREAM_END)) {
                    log("unable to read control data \(lenread) \(cbz2err.pointee)")
                    throw BRBSPatchError.corruptPatch
                }
                crtl[i] = offtin(UnsafePointer<CUnsignedChar>(buf))
            }
            // sanity check
            if (newPos + crtl[0]) > newSize {
                log("incorrect size of crtl[0]")
                throw BRBSPatchError.corruptPatch
            }
            
            // read diff string
            let dlenread = BZ2_bzRead(dbz2err, dpfbz2, new + Int(newPos), Int32(crtl[0]))
            if (dlenread < Int32(crtl[0])) || ((dbz2err.pointee != BZ_OK) && (dbz2err.pointee != BZ_STREAM_END)) {
                log("unable to read diff string \(dlenread) \(dbz2err.pointee)")
                throw BRBSPatchError.corruptPatch
            }
            
            // add old data to diff string
            if crtl[0] > 0 {
                for i in 0...(Int(crtl[0]) - 1) {
                    if (oldPos + i >= 0) && (oldPos + i < oldSize) {
                        let np = Int(newPos) + i, op = Int(oldPos) + i
                        new[np] = new[np] &+ old[op]
                    }
                }
            }
            
            // adjust pointers
            newPos += crtl[0]
            oldPos += crtl[0]
            
            // sanity check
            if (newPos + crtl[1]) > newSize {
                log("incorrect size of crtl[1]")
                throw BRBSPatchError.corruptPatch
            }
            
            // read extra string
            let elenread = BZ2_bzRead(ebz2err, epfbz2, new + Int(newPos), Int32(crtl[1]))
            if (elenread < Int32(crtl[1])) || ((ebz2err.pointee != BZ_OK) && (ebz2err.pointee != BZ_STREAM_END)) {
                log("unable to read extra string \(elenread) \(ebz2err.pointee)")
                throw BRBSPatchError.corruptPatch
            }
            
            // adjust pointers
            newPos += crtl[1]
            oldPos += crtl[2]
        }
        
        // clean up bz2 reads
        BZ2_bzReadClose(cbz2err, cpfbz2)
        BZ2_bzReadClose(dbz2err, dpfbz2)
        BZ2_bzReadClose(ebz2err, epfbz2)
        
        if (fclose(cpf) != 0) || (fclose(dpf) != 0) || (fclose(epf) != 0) {
            log("unable to close bzip file handles")
            throw BRBSPatchError.unknown
        }
        
        // write out new file
        let fm = FileManager.default
        if fm.fileExists(atPath: newFilePath) {
            try fm.removeItem(atPath: newFilePath)
        }
        let newData = Data(bytes: UnsafePointer<UInt8>(new), count: Int(newSize))
        try newData.write(to: URL(fileURLWithPath: newFilePath), options: .atomic)
        return new
    }
    
    static fileprivate func log(_ string: String) {
        if patchLogEnabled {
            print("[BRBSPatch] \(string)")
        }
    }
}
