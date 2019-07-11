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
    
    static let hasShownInAppNotificationKeyPrefix = "showed-in-app-notification"
    
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

//
// In-app notification handling.
//
extension NotificationHandler {
    
    private func inAppNotificationKey(for id: String) -> String {
        return NotificationHandler.hasShownInAppNotificationKeyPrefix + id
    }
    
    private func setHasProcessedNotificationId(_ id: String) {
        UserDefaults.standard.set(true, forKey: inAppNotificationKey(for: id))
    }
    
    private func hasProcessedNotificationId(_ id: String) -> Bool {
        return UserDefaults.standard.bool(forKey: inAppNotificationKey(for: id))
    }
    
    private func logReceivedEvent(for notification: BRDMessage) {
        let eventName = self.makeEventName([EventContext.inAppNotifications.name, Event.receivedNotification.name])
        var attributes: [String: String] = [String: String]()
        
        if let id = notification.id {
            attributes[BRDMessage.Keys.id.rawValue] = id
        }

        if let msgId = notification.messageId {
            attributes[BRDMessage.Keys.message_id.rawValue] = msgId
        }
        
        self.saveEvent(eventName, attributes: attributes)
    }
    
    func checkForInAppNotifications() {
        Backend.apiClient.checkMessages { [weak self] (messages) in
            guard let `self` = self else { return }
            guard let msgs = messages, !msgs.isEmpty else { return }
            
            // Filter on in-app messages.
            let inAppNotifications = msgs.filter({ return $0.type == BRDMessageType.inApp.type() })
                        
            if let notification = inAppNotifications.first, let msgId = notification.messageId, !self.hasProcessedNotificationId(msgId) {
                self.setHasProcessedNotificationId(msgId)
                self.logReceivedEvent(for: notification)
                Store.trigger(name: .showInAppNotification(notification))
            }
        }
    }
}
