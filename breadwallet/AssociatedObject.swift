//
//  AssociatedObject.swift
//  breadwallet
//
//  Created by Samuel Sutch on 4/1/17.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation

func associatedObject<T: AnyObject>(_ base: AnyObject, key: UnsafePointer<UInt8>, initialiser: () -> T) -> T {
    if let associated = objc_getAssociatedObject(base, key) as? T {
        return associated
    }
    let associated = initialiser()
    objc_setAssociatedObject(base, key, associated, .OBJC_ASSOCIATION_RETAIN)
    return associated
}

func lazyAssociatedObject<T: AnyObject>(_ base: AnyObject, key: UnsafePointer<UInt8>, initialiser: () -> T?) -> T? {
    if let associated = objc_getAssociatedObject(base, key) as? T {
        return associated
    }
    if let associated = initialiser() {
        objc_setAssociatedObject(base, key, associated, .OBJC_ASSOCIATION_RETAIN)
        return associated
    }
    return nil
}

func associateObject<T: AnyObject>(_ base: AnyObject, key: UnsafePointer<UInt8>, value: T) {
    objc_setAssociatedObject(base, key, value, .OBJC_ASSOCIATION_RETAIN)
}
