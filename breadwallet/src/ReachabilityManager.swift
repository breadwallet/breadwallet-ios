//
//  ReachabilityManager.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-06-17.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation
import SystemConfiguration


private func callback(reachability:SCNetworkReachability, flags: SCNetworkReachabilityFlags, info: UnsafeMutableRawPointer?) {
    guard let info = info else { return }
    let reachability = Unmanaged<ReachabilityManager>.fromOpaque(info).takeUnretainedValue()
    reachability.notify()
}

class ReachabilityManager {

    init(host: String) {
        networkReachability = SCNetworkReachabilityCreateWithName(kCFAllocatorDefault, host)
        start()
    }

    var didChange: ((Bool) -> Void)?

    private var networkReachability: SCNetworkReachability?
    private let reachabilitySerialQueue = DispatchQueue(label: "com.breadwallet.reachabilityQueue")

    func notify() {
        DispatchQueue.main.async {
            self.didChange?(self.isReachable)
        }
    }

    var isReachable: Bool {
        return flags.contains(.reachable)
    }

    private func start() {
        var context = SCNetworkReachabilityContext()
        context.info = UnsafeMutableRawPointer(Unmanaged<ReachabilityManager>.passUnretained(self).toOpaque())
        guard let reachability = networkReachability else { return }
        SCNetworkReachabilitySetCallback(reachability, callback, &context)
        SCNetworkReachabilitySetDispatchQueue(reachability, reachabilitySerialQueue)
    }

    private var flags: SCNetworkReachabilityFlags {
        var flags = SCNetworkReachabilityFlags(rawValue: 0)
        if let reachability = networkReachability, withUnsafeMutablePointer(to: &flags, { SCNetworkReachabilityGetFlags(reachability, UnsafeMutablePointer($0)) }) == true {
            return flags
        }
        else {
            return []
        }
    }
}
