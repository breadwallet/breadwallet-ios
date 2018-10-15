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
        #if targetEnvironment(simulator)
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
    
    static let isRunningTests: Bool = {
        #if Debug
            return ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        #else
            return false
        #endif
    }()
    
    static var isIPhone4: Bool {
        return UIApplication.shared.keyWindow?.bounds.height == 480.0
    }
    
    static let isIPhoneX: Bool = {
        return (UIScreen.main.bounds.size.height == 812.0) || (UIScreen.main.bounds.size.height == 896.0)
    }()
    
    static let osVersion: String = {
        let os = ProcessInfo().operatingSystemVersion
        return String(os.majorVersion) + "." + String(os.minorVersion) + "." + String(os.patchVersion)
    }()
}
