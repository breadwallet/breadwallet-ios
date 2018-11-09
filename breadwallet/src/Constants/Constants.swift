//
//  Constants.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-24.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

let π: CGFloat = .pi

struct Padding {
    var increment: CGFloat
    
    subscript(multiplier: Int) -> CGFloat {
        return CGFloat(multiplier) * increment
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
    }
    static var defaultTintColor: UIColor = {
        return UIView().tintColor
    }()
    static let animationDuration: TimeInterval = 0.3
    static let secondsInDay: TimeInterval = 86400
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
    static let feeCacheTimeout: TimeInterval = C.secondsInDay*3
    static let bCashForkBlockHeight: UInt32 = E.isTestnet ? 1155876 : 478559
    static let bCashForkTimeStamp: TimeInterval = E.isTestnet ? (1501597117 - NSTimeIntervalSince1970) : (1501568580 - NSTimeIntervalSince1970)
    static let txUnconfirmedHeight = Int32.max
    static var logFilePath: URL {
        let cachesDirectory = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first!
        return URL(fileURLWithPath: cachesDirectory).appendingPathComponent("log.txt")
    }
    static let usdCurrencyCode = "USD"
    static let erc20Prefix = "erc20:"
    
    #if Debug || Testflight
        static let webBundle = "brd-web-3-staging"
    #else
        static let webBundle = "brd-web-3" // should match AssetBundles.plist
    #endif
}

enum Words {
    static var wordList: [NSString]? {
        guard let path = Bundle.main.path(forResource: "BIP39Words", ofType: "plist") else { return nil }
        return NSArray(contentsOfFile: path) as? [NSString]
    }

    static var rawWordList: [UnsafePointer<CChar>?]? {
        guard let wordList = Words.wordList, wordList.count == 2048 else { return nil }
        return wordList.map({ $0.utf8String })
    }
}
