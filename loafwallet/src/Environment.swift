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
    static let isRelease: Bool = {
        #if Release
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
    static var isIPhone4: Bool {
        return UIApplication.shared.keyWindow?.bounds.height == 480.0
    }
    static var isIPhone5: Bool {
        return (UIApplication.shared.keyWindow?.bounds.height == 568.0) && (E.is32Bit)
    }
    static var isIPhoneX: Bool {
        return (UIScreen.main.bounds.size.height == 812.0)
    }
    static var isIPhone8Plus: Bool {
      return (UIScreen.main.bounds.size.height == 736.0)
    }
    static var isIPhoneXsMax: Bool {
      return (UIScreen.main.bounds.size.height == 812.0)
    }
    static var isIPad: Bool {
        return (UIDevice.current.userInterfaceIdiom == .pad)
    }
    static let is32Bit: Bool = {
        return MemoryLayout<Int>.size == MemoryLayout<UInt32>.size
    }()
  
    static var screenHeight: CGFloat {
      return UIScreen.main.bounds.size.height
    }
}

struct EnvironmentVariables {
    
    static let plistDict: NSDictionary? = {
        var dict: NSDictionary?
               if let path = Bundle.main.path(forResource: "EnvVars", ofType: "plist") {
                  dict = NSDictionary(contentsOfFile: path)
               }
        return dict
    }()
    
    static var mixpanelProdToken: String = EnvironmentVariables.plistVariable(name: "MXP_PROD_ENV") ?? CI.mixpanelProdToken
    static var mixpanelDevToken: String = EnvironmentVariables.plistVariable(name: "MXP_DEV_ENV") ?? CI.mixpanelDevToken

    static func plistVariable(name: String) -> String? {
        if let key = plistDict?[name] as? String {
            return key
        }
        return nil
    }
    
    enum EnvironmentName: String {
        case debug      = "Debug"
        case release    = "Release"
    }
}
