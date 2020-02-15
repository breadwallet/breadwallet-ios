//
//  Constants.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-24.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

let π: CGFloat = .pi
let kDonationAmount: UInt64 = 900000 //UInt64
let kDonationAmountInDouble: Double = Double(kDonationAmount) / Double(100000000)

let kDonationAddress1 = "MDPqwDf9eUErGLcZNt1HN9HqnbFCSCSRme"


enum MixpanelEvents: String {
    case _20191105_AL = "APP_LAUNCHED"
    case _20191105_VSC = "VISIT_SEND_CONTROLLER"
    case _20191105_DSL = "DID_SEND_LTC"
    case _20191105_DULP = "DID_UPDATE_LTC_PRICE" 
    case _20191105_DTBT = "DID_TAP_BUY_TAB"
    case _20200111_DEDG = "DID_ENTER_DISPATCH_GROUP"
    case _20200111_DLDG = "DID_LEAVE_DISPATCH_GROUP"
    case _20200111_RNI = "RATE_NOT_INITIALIZED"
    case _20200111_FNI = "FEEPERKB_NOT_INITIALIZED"
    case _20200111_TNI = "TRANSACTION_NOT_INITIALIZED"
    case _20200111_WNI = "WALLET_NOT_INITIALIZED"
    case _20200111_PNI = "PHRASE_NOT_INITIALIZED"
    case _20200111_UTST = "UNABLE_TO_SIGN_TRANSACTION"
    case _20200112_ERR = "ERROR"
    case _20200112_DSR = "DID_START_RESYNC"
    case _20200125_DSRR = "DID_SHOW_REVIEW_REQUEST" 
}

struct Padding {
    subscript(multiplier: Int) -> CGFloat {
        get {
            return CGFloat(multiplier) * 8.0
        }
    }
}
  
struct DonationAddress {
    
    static let firstLF: String = kDonationAddress1
}

struct C {
    static let padding = Padding()
    struct Sizes {
        static let buttonHeight: CGFloat = 48.0
        static let headerHeight: CGFloat = 48.0
        static let largeHeaderHeight: CGFloat = 220.0
        static let logoAspectRatio: CGFloat = 125.0/417.0
    }
    static var defaultTintColor: UIColor = {
        return UIView().tintColor
    }()
    static let animationDuration: TimeInterval = 0.3
    static let secondsInDay: TimeInterval = 86400
    static let maxMoney: UInt64 = 84000000*100000000
    static let satoshis: UInt64 = 100000000
    static let walletQueue = "com.litecoin.walletqueue"
    static let btcCurrencyCode = "LTC"
    static let null = "(null)"
    static let maxMemoLength = 250
    static let feedbackEmail = "iosagent+feeback@litecoinfoundation.net"
    static let reviewLink = "https://itunes.apple.com/app/loafwallet-litecoin-wallet/id1119332592?action=write-review"
    static var standardPort: Int {
        return E.isTestnet ? 19335 : 9333
    }
}

struct AppVersion {
    static let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
    static let versionNumber = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    static let string = "v." + versionNumber! + " (\(buildNumber!))"
}
