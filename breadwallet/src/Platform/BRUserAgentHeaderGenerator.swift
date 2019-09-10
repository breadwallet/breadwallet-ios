//
//  BRUserAgentHeaderGenerator.swift
//  breadwallet
//
//  Created by Ray Vander Veen on 2019-01-16.
//  Copyright © 2019 Breadwinner AG. All rights reserved.
//

import UIKit

typealias BRAppVersion = (major: String, minor: String, hotfix: String, build: String)

/**
 *  Encapsulates the generation of a well formed User-Agent header value as expected by the BRD back end.
 */
public class BRUserAgentHeaderGenerator {
    
    /**
     *  Returns a string to be used as the User-Agent HTTP header value in requests to the BRD back end.
     *
     *  A typical value will be something such as "breadwallet/3070390 CFNetwork/975.0.3 Darwin/18.2.0"
     *
     *  The server will focus on the app version string, in this case 3070390, which represents 3.7.0 (390).
     */
    static let userAgentHeader: String = {
        let appName = appNameString()
        let appVersion = appVersionString(with: brdAppVersion())
        let darwinVersion = darwinVersionString()
        let cfNetworkVersion = cfNetworkVersionString()
        
        let header = userAgentHeaderString(appName: appName,
                                           appVersion: appVersion,
                                           darwinVersion: darwinVersion,
                                           cfNetworkVersion: cfNetworkVersion)
        return header
    }()
    
    static func userAgentHeaderString(appName: String,
                                      appVersion: String,
                                      darwinVersion: String,
                                      cfNetworkVersion: String) -> String {
        return "\(appName)/\(appVersion) \(cfNetworkVersion) \(darwinVersion)"
    }
    
    private static func brdAppVersion() -> BRAppVersion {
        guard
            let info = Bundle.main.infoDictionary,
            let version = info["CFBundleShortVersionString"] as? String,
            let build = info["CFBundleVersion"] as? String else {
                return BRAppVersion("0", "0", "0", "0")
        }
        
        var major = "0"
        var minor = "0"
        var hotfix = "0"
        
        let versionComponents = version.components(separatedBy: ".")
        
        if !versionComponents.isEmpty {
            major = versionComponents[0]
        }
        
        if versionComponents.count > 1 {
            minor = versionComponents[1]
        }
        
        if versionComponents.count > 2 {
            hotfix = versionComponents[2]
        }
        
        return BRAppVersion(major, minor, hotfix, build)
    }

    static func appVersionString(with appVersion: BRAppVersion) -> String {
        var header: String = ""
        
        if !appVersion.major.isEmpty {
            header += appVersion.major
        }
        
        // minor version should be two digits, so if it's only one, prefix with "0"
        header += appVersion.minor.leftPadding(toLength: 2, withPad: "0")
        
        // third component of the version is for hotfixes, such as the "1" in version "3.7.1"
        header += appVersion.hotfix
        
        // if the build number is under three digits, prefix with zeros
        header += appVersion.build.leftPadding(toLength: 3, withPad: "0")

        return header
    }

    private static func appNameString() -> String {
        guard
            let info = Bundle.main.infoDictionary as NSDictionary?,
            let name = info["CFBundleName"] as? String else {
                return "breadwallet"
        }
        return name
    }
    
    private static func cfNetworkVersionString() -> String {
        guard
            let info = Bundle(identifier: "com.apple.CFNetwork")?.infoDictionary as NSDictionary?,
            let version = info["CFBundleShortVersionString"] as? String else {
                return "CFNetwork/0"
        }
        
        return "CFNetwork/\(version)"
    }
    
    private static func darwinVersionString() -> String {
        var sysinfo = utsname()
        
        uname(&sysinfo)
        
        guard
            var version = String(bytes: Data(bytes: &sysinfo.release,
                                             count: Int(_SYS_NAMELEN)),
                                 encoding: .ascii)
            else {
                return "Darwin/0"
        }
        
        version = version.trimmingCharacters(in: .controlCharacters)
        
        return "Darwin/\(version)"
    }
    
}
