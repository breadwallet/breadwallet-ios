//
//  SecureAllocator.swift
//  breadwallet
//
//  Created by Aaron Voisine on 12/11/16.
//  Copyright (c) 2016-2019 Breadwinner AG. All rights reserved.
//

import Foundation

private func secureAllocate(allocSize: CFIndex, hint: CFOptionFlags, info: UnsafeMutableRawPointer?)
    -> UnsafeMutableRawPointer? {
    guard let ptr = malloc(MemoryLayout<CFIndex>.stride + allocSize) else { return nil }
    // keep track of the size of the allocation so it can be cleansed before deallocation
    ptr.storeBytes(of: allocSize, as: CFIndex.self)
    return ptr.advanced(by: MemoryLayout<CFIndex>.stride)
}

private func secureDeallocate(ptr: UnsafeMutableRawPointer?, info: UnsafeMutableRawPointer?) {
    guard let ptr = ptr else { return }
    let allocSize = ptr.load(fromByteOffset: -MemoryLayout<CFIndex>.stride, as: CFIndex.self)
    memset(ptr, 0, allocSize) // cleanse allocated memory
    free(ptr.advanced(by: -MemoryLayout<CFIndex>.stride))
}

private func secureReallocate(ptr: UnsafeMutableRawPointer?,
                              newsize: CFIndex,
                              hint: CFOptionFlags,
                              info: UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer? {
    // there's no way to tell ahead of time if the original memory will be deallocted even if the new size is smaller
    // than the old size, so just cleanse and deallocate every time
    guard let ptr = ptr else { return nil }
    let newptr = secureAllocate(allocSize: newsize, hint: hint, info: info)
    let allocSize = ptr.load(fromByteOffset: -MemoryLayout<CFIndex>.stride, as: CFIndex.self)
    if newptr != nil { memcpy(newptr, ptr, (allocSize < newsize) ? allocSize : newsize) }
    secureDeallocate(ptr: ptr, info: info)
    return newptr
}

// since iOS does not page memory to disk, all we need to do is cleanse allocated memory prior to deallocation
public let secureAllocator: CFAllocator = {
    var context = CFAllocatorContext()
    context.version = 0
    CFAllocatorGetContext(kCFAllocatorDefault, &context)
    context.allocate = secureAllocate
    context.reallocate = secureReallocate
    context.deallocate = secureDeallocate
    return CFAllocatorCreate(kCFAllocatorDefault, &context).takeRetainedValue()
}()
