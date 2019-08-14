//
//  BRCore.swift
//  breadwallet
//
//  Created by Aaron Voisine on 12/11/16.
//  Copyright (c) 2016-2019 Breadwinner AG. All rights reserved.
//

import Foundation
import BRCore

typealias BRTxRef = UnsafeMutablePointer<BRTransaction>
typealias BRBlockRef = UnsafeMutablePointer<BRMerkleBlock>

private func secureAllocate(allocSize: CFIndex, hint: CFOptionFlags, info: UnsafeMutableRawPointer?)
    -> UnsafeMutableRawPointer?
{
    guard let ptr = malloc(MemoryLayout<CFIndex>.stride + allocSize) else { return nil }
    // keep track of the size of the allocation so it can be cleansed before deallocation
    ptr.storeBytes(of: allocSize, as: CFIndex.self)
    return ptr.advanced(by: MemoryLayout<CFIndex>.stride)
}

private func secureDeallocate(ptr: UnsafeMutableRawPointer?, info: UnsafeMutableRawPointer?)
{
    guard let ptr = ptr else { return }
    let allocSize = ptr.load(fromByteOffset: -MemoryLayout<CFIndex>.stride, as: CFIndex.self)
    memset(ptr, 0, allocSize) // cleanse allocated memory
    free(ptr.advanced(by: -MemoryLayout<CFIndex>.stride))
}

private func secureReallocate(ptr: UnsafeMutableRawPointer?, newsize: CFIndex, hint: CFOptionFlags,
                              info: UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer?
{
    // there's no way to tell ahead of time if the original memory will be deallocted even if the new size is smaller
    // than the old size, so just cleanse and deallocate every time
    guard let ptr = ptr else { return nil }
    let newptr = secureAllocate(allocSize: newsize, hint: hint, info: info)
    let allocSize = ptr.load(fromByteOffset: -MemoryLayout<CFIndex>.stride, as: CFIndex.self)
    if (newptr != nil) { memcpy(newptr, ptr, (allocSize < newsize) ? allocSize : newsize) }
    secureDeallocate(ptr: ptr, info: info)
    return newptr
}

// since iOS does not page memory to disk, all we need to do is cleanse allocated memory prior to deallocation
public let secureAllocator: CFAllocator = {
    var context = CFAllocatorContext()
    context.version = 0;
    CFAllocatorGetContext(kCFAllocatorDefault, &context)
    context.allocate = secureAllocate
    context.reallocate = secureReallocate;
    context.deallocate = secureDeallocate;
    return CFAllocatorCreate(kCFAllocatorDefault, &context).takeRetainedValue()
}()

// 8 element tuple equatable
public func == <A: Equatable, B: Equatable, C: Equatable, D: Equatable, E: Equatable, F: Equatable, G: Equatable,
                H: Equatable>(l: (A, B, C, D, E, F, G, H), r: (A, B, C, D, E, F, G, H)) -> Bool {
    return l.0 == r.0 && l.1 == r.1 && l.2 == r.2 && l.3 == r.3 && l.4 == r.4 && l.5 == r.5 && l.6 == r.6 && l.7 == r.7
}

public func != <A: Equatable, B: Equatable, C: Equatable, D: Equatable, E: Equatable, F: Equatable, G: Equatable,
                H: Equatable>(l: (A, B, C, D, E, F, G, H), r: (A, B, C, D, E, F, G, H)) -> Bool {
    return l.0 != r.0 || l.1 != r.1 || l.2 != r.2 || l.3 != r.3 || l.4 != r.4 || l.5 != r.5 || l.6 != r.6 || l.7 != r.7
}

// 33 element tuple equatable
public func == <A: Equatable, B: Equatable, C: Equatable, D: Equatable, E: Equatable, F: Equatable, G: Equatable,
                H: Equatable, I: Equatable, J: Equatable, K: Equatable, L: Equatable, M: Equatable, N: Equatable,
                O: Equatable, P: Equatable, Q: Equatable, R: Equatable, S: Equatable, T: Equatable, U: Equatable,
                V: Equatable, W: Equatable, X: Equatable, Y: Equatable, Z: Equatable, a: Equatable, b: Equatable,
                c: Equatable, d: Equatable, e: Equatable, f: Equatable, g: Equatable>
    (l: (A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P, Q, R, S, T, U, V, W, X, Y, Z, a, b, c, d, e, f, g),
     r: (A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P, Q, R, S, T, U, V, W, X, Y, Z, a, b, c, d, e, f, g)) -> Bool {
    return l.0 == r.0 && l.1 == r.1 && l.2 == r.2 && l.3 == r.3 && l.4 == r.4 && l.5 == r.5 && l.6 == r.6 &&
        l.7 == r.7 && l.8 == r.8 && l.9 == r.9 && l.10 == r.10 && l.11 == r.11 && l.12 == r.12 && l.13 == r.13 &&
        l.14 == r.14 && l.15 == r.15 && l.16 == r.16 && l.17 == r.17 && l.18 == r.18 && l.19 == r.19 && l.20 == r.20 &&
        l.21 == r.21 && l.22 == r.22 && l.23 == r.23 && l.24 == r.24 && l.25 == r.25 && l.26 == r.26 && l.27 == r.27 &&
        l.28 == r.28 && l.29 == r.29 && l.30 == r.30 && l.31 == r.31 && l.32 == r.32
}

public func != <A: Equatable, B: Equatable, C: Equatable, D: Equatable, E: Equatable, F: Equatable, G: Equatable,
                H: Equatable, I: Equatable, J: Equatable, K: Equatable, L: Equatable, M: Equatable, N: Equatable,
                O: Equatable, P: Equatable, Q: Equatable, R: Equatable, S: Equatable, T: Equatable, U: Equatable,
                V: Equatable, W: Equatable, X: Equatable, Y: Equatable, Z: Equatable, a: Equatable, b: Equatable,
                c: Equatable, d: Equatable, e: Equatable, f: Equatable, g: Equatable>
    (l: (A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P, Q, R, S, T, U, V, W, X, Y, Z, a, b, c, d, e, f, g),
     r: (A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P, Q, R, S, T, U, V, W, X, Y, Z, a, b, c, d, e, f, g)) -> Bool {
    return l.0 != r.0 || l.1 != r.1 || l.2 != r.2 || l.3 != r.3 || l.4 != r.4 || l.5 != r.5 || l.6 != r.6 ||
        l.7 != r.7 || l.8 != r.8 || l.9 != r.9 || l.10 != r.10 || l.11 != r.11 || l.12 != r.12 || l.13 != r.13 ||
        l.14 != r.14 || l.15 != r.15 || l.16 != r.16 || l.17 != r.17 || l.18 != r.18 || l.19 != r.19 || l.20 != r.20 ||
        l.21 != r.21 || l.22 != r.22 || l.23 != r.23 || l.24 != r.24 || l.25 != r.25 || l.26 != r.26 || l.27 != r.27 ||
        l.28 != r.28 || l.29 != r.29 || l.30 != r.30 || l.31 != r.31 || l.32 != r.32
}
