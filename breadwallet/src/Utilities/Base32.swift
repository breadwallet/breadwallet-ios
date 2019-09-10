// 
//  Base32.swift
//  breadwallet
//
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

import Foundation

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
