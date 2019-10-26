//
//  Constants.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-24.
//  Copyright © 2016-2019 Breadwinner AG. All rights reserved.
//

import UIKit

let π: CGFloat = .pi

struct Padding {
    var increment: CGFloat
    
    subscript(multiplier: Int) -> CGFloat {
        return CGFloat(multiplier) * increment
    }
    
    static var half: CGFloat {
        return C.padding[1]/2.0
    }
}

// swiftlint:disable type_name
/// Constants
struct C {
    static let padding = Padding(increment: 8.0)
    struct Sizes {
        static let buttonHeight: CGFloat = 48.0
        static let headerHeight: CGFloat = 48.0
        static let largeHeaderHeight: CGFloat = 220.0
        static let logoAspectRatio: CGFloat = 125.0/417.0
        static let cutoutLogoAspectRatio: CGFloat = 342.0/553.0
        static let roundedCornerRadius: CGFloat = 6.0
        static let homeCellCornerRadius: CGFloat = 2.0
        static let brdLogoHeight: CGFloat = 32.0
        static let brdLogoTopMargin: CGFloat = E.isIPhoneX ? C.padding[9] + 35.0 : C.padding[9] + 20.0
    }
    static var defaultTintColor: UIColor = {
        return UIView().tintColor
    }()
    static let animationDuration: TimeInterval = 0.3
    static let secondsInDay: TimeInterval = 86400
    static let secondsInMinute: TimeInterval = 60
    static let maxMoney: UInt64 = 21000000*100000000
    static let satoshis: UInt64 = 100000000
    static let walletQueue = "com.breadwallet.walletqueue"
    static let null = "(null)"
    static let maxMemoLength = 250
    static let feedbackEmail = "feedback@breadapp.com"
    static let iosEmail = "ios@breadapp.com"
    static let reviewLink = "https://itunes.apple.com/app/breadwallet-bitcoin-wallet/id885251393?action=write-review"
    static var standardPort: Int {
        return E.isTestnet ? 18333 : 8333
    }
    static let bip39CreationTime = TimeInterval(1388534400) - NSTimeIntervalSince1970
    static let bCashForkBlockHeight: UInt32 = E.isTestnet ? 1155876 : 478559
    static let bCashForkTimeStamp: TimeInterval = E.isTestnet ? (1501597117 - NSTimeIntervalSince1970) : (1501568580 - NSTimeIntervalSince1970)
    static let txUnconfirmedHeight = Int32.max

    /// Path where core library stores its persistent data
    static var coreDataDirURL: URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsURL.appendingPathComponent("core-data", isDirectory: true)
    }
    
    static let consoleLogFileName = "log.txt"
    static let previousConsoleLogFileName = "previouslog.txt"
    
    // Returns the console log file path for the current instantiation of the app.
    static var logFilePath: URL {
        let cachesURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return cachesURL.appendingPathComponent(consoleLogFileName)
    }
    
    // Returns the console log file path for the previous instantiation of the app.
    static var previousLogFilePath: URL {
        let cachesURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return cachesURL.appendingPathComponent(previousConsoleLogFileName)
    }
    
    static let usdCurrencyCode = "USD"
    static let euroCurrencyCode = "EUR"
    static let britishPoundCurrencyCode = "GBP"
    static let danishKroneCurrencyCode = "DKK"
    static let erc20Prefix = "erc20:"

    static var backendHost: String {
        if let debugBackendHost = UserDefaults.debugBackendHost {
            return debugBackendHost
        } else {
            return (E.isDebug || E.isTestFlight) ? "stage2.breadwallet.com" : "api.breadwallet.com"
        }
    }

    static var webBundle: String {
        if let debugWebBundle = UserDefaults.debugWebBundleName {
            return debugWebBundle
        } else {
            // names should match AssetBundles.plist
            return (E.isDebug || E.isTestFlight) ? "brd-web-3-staging" : "brd-web-3"
        }
    }

    static var bdbHost: String {
        return "api.blockset.com"
    }

    static let bdbClientTokenRecordId = "BlockchainDBClientID"
    
    static let daiContractAddress = "0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359"
    static let daiContractCode = "DAI"
    
    static let tusdContractAddress = "0x0000000000085d4780B73119b644AE5ecd22b376"
    static let tusdContractCode = "TUSD"
}

enum Words {
    static var wordList: [NSString]? {
        guard let path = Bundle.main.path(forResource: "BIP39Words", ofType: "plist") else { return nil }
        return NSArray(contentsOfFile: path) as? [NSString]
    }
}
