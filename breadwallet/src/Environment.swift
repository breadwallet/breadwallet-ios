//
//  Environment.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-06-20.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

struct E {
    static let isTestnet: Bool = {
        #if Testnet
            return true
        #else
            return false
        #endif
    }()
    static let isTestFlight: Bool = {
        #if Testflight
            return true
        #else
            return false
        #endif
    }()
    static let isSimulator: Bool = {
        #if arch(i386) || arch(x86_64)
            return true
        #else
            return false
        #endif
    }()
    static let isDebug: Bool = {
        #if Debug
            return true
        #else
            return false
        #endif
    }()
    static let isScreenshots: Bool = {
        #if Screenshots
            return true
        #else
            return false
        #endif
    }()
    static let isIPhone4: Bool = {
        return UIApplication.shared.keyWindow?.bounds.height == 480.0
    }()
    static let isIPhone5: Bool = {
        return (UIApplication.shared.keyWindow?.bounds.height == 568.0) && (E.is32Bit)
    }()
    static let is32Bit: Bool = {
        return MemoryLayout<Int>.size == MemoryLayout<UInt32>.size
    }()
}
