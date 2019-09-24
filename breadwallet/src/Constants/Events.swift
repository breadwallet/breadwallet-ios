//
//  Events.swift
//  breadwallet
//
//  Created by Ray Vander Veen on 2019-02-13.
//  Copyright © 2019 Breadwinner AG. All rights reserved.
//

import Foundation

public enum EventContext: String {
    case none
    case test
    case onboarding
    case generateKey
    case writeKey
    case rewards
    case pushNotifications
    case inAppNotifications
    case wallet
    case jailbreak
    case fastSync
    var name: String { return rawValue }
}

public enum Event: String {
    
    case none = ""
    
    case appeared
    case confirm
    case pinKeyed
    case pinCreated
    case pinCreationError
    case dismissed
    case paperKeyCreated
    case paperKeyError
    case complete
    
    // general buttons (tapped)
    case helpButton
    case writeDownButton
    case generatePaperKeyButton
    
    // onboarding buttons (tapped)
    case getStartedButton
    case restoreWalletButton
    case backButton
    case skipButton
    case nextButton
    case browseFirstButton
    case buyCoinButton

    case openWallet
    case banner
    
    // buttons
    case okButton
    case deferButton
    case allowButton
    case denyButton
    
    // enable/disable push notifications
    case pushNotificationsToggleOn
    case pushNotificationsToggleOff
    
    // open notification system settings for BRD
    case openNotificationSystemSettings
    
    // user opened a push notification
    case openNotification

    case iOSError
    
    // received notification
    case receivedNotification

    // tapped notification viewer CTA button
    case notificationCTAButton
    
    // charts
    case axisToggle
    case scrubbed
    
    case test
    
    //jailbreak actions
    case ignore
    case close
    
    // fastSync
    case enable
    case disable
    
    var name: String { return rawValue }
}

public enum Screen: String {
    
    case none = ""
    
    // general screens
    case setPin
    case paperKeyIntro
    case writePaperKey
    case confirmPaperKey
    
    // onboarding screens
    case landingPage
    case globePage
    case coinsPage
    case finalPage

    // push notifications
    case optInPrompt
    case systemPrompt
    case pushNotificationSettings
    
    // in-app notifications
    case inAppNotification
    
    case test

    var name: String { return rawValue }
}
