//
//  NotificationHandler.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2018-07-16.
//  Copyright © 2018 breadwallet LLC. All rights reserved.
//

import Foundation
import UIKit
import UserNotifications

class NotificationHandler: NSObject, UNUserNotificationCenterDelegate, Trackable {
    
    // received while app is background
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        
        var eventAttributes: [String: String]?

        let json = response.notification.request.content.userInfo
        
        if let brdData = json["brd"] as? [String: String],
            let url = brdData["url"],
            let URL = URL(string: url) {
            
            UIApplication.shared.open(URL)
            
            // Pass all the BRD attributes back with the analytics event to help correlate push campaigns
            // with the back-end analytics. 
            eventAttributes = brdData
        }
        
        saveEvent(context: .pushNotifications, screen: .none, event: .openNotification, attributes: eventAttributes ?? [:], callback: nil)

        // inbox is always fetched after unlock
        completionHandler()
    }

    // received while app is foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        
        print("received notification: \(notification)")
        if !Store.state.isLoginRequired {
            Store.trigger(name: .fetchInbox)
        }
        completionHandler([])
    }
}
