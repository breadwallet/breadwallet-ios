//
//  Main.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-02-17.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

private func delegateClassName() -> String? {
    return NSClassFromString("XCTestCase") == nil ? NSStringFromClass(AppDelegate.self) : nil
}

private let unsafeArgv = UnsafeMutableRawPointer(CommandLine.unsafeArgv)
                            .bindMemory(
                                to: UnsafeMutablePointer<Int8>.self,
                                capacity: Int(CommandLine.argc))

UIApplicationMain(CommandLine.argc, unsafeArgv, nil, delegateClassName())
