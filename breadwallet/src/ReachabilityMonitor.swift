//
//  ReachabilityManager.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-06-17.
//  Copyright © 2017-2019 Breadwinner AG. All rights reserved.
//

import Foundation
import SystemConfiguration

private func callback(reachability: SCNetworkReachability, flags: SCNetworkReachabilityFlags, info: UnsafeMutableRawPointer?) {
    guard let info = info else { return }
    let reachability = Unmanaged<Reachability>.fromOpaque(info).takeUnretainedValue()
    reachability.notify()
}

class Reachability {

    private static let shared = Reachability()
    private var didChangeCallbacks = [((Bool) -> Void)]()
    private var networkReachability: SCNetworkReachability?
    private let reachabilitySerialQueue = DispatchQueue(label: "com.breadwallet.reachabilityQueue")

    private init() {
        networkReachability = SCNetworkReachabilityCreateWithName(kCFAllocatorDefault, "google.com")
        start()
    }

    static func addDidChangeCallback(_ callback: @escaping (Bool) -> Void) {
        shared.didChangeCallbacks.append(callback)
    }

    static var isReachable: Bool {
        return shared.flags.contains(.reachable)
    }

    func notify() {
        DispatchQueue.main.async {
            self.didChangeCallbacks.forEach {
                $0(Reachability.isReachable)
            }
        }
    }

    private func start() {
        var context = SCNetworkReachabilityContext()
        context.info = UnsafeMutableRawPointer(Unmanaged<Reachability>.passUnretained(self).toOpaque())
        guard let reachability = networkReachability else { return }
        SCNetworkReachabilitySetCallback(reachability, callback, &context)
        SCNetworkReachabilitySetDispatchQueue(reachability, reachabilitySerialQueue)
    }

    private var flags: SCNetworkReachabilityFlags {
        var flags = SCNetworkReachabilityFlags(rawValue: 0)
        if let reachability = networkReachability,
            withUnsafeMutablePointer(to: &flags, { SCNetworkReachabilityGetFlags(reachability, UnsafeMutablePointer($0)) }) == true {
            return flags
        } else {
            return []
        }
    }
}
