//
//  NotificationHandler.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2018-07-16.
//  Copyright © 2018-2019 Breadwinner AG. All rights reserved.
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

        // Log an event for the push notification campaign if applicable.
        if let messageInfo = json["mp"] as? [String: Any], let campaignId = messageInfo["c"] as? Int {
            saveEvent("$app_open", attributes: ["campaign_id": String(campaignId)])
        }

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

extension BRAPIClient {
    
    func savePushNotificationToken(_ token: Data) {
        var req = URLRequest(url: url("/me/push-devices"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let reqJson = [
            "token": token.hexString,
            "service": "apns",
            "data": [   "e": pushNotificationEnvironment(),
                        "b": Bundle.main.bundleIdentifier!]
            ] as [String: Any]
        do {
            let dat = try JSONSerialization.data(withJSONObject: reqJson, options: .prettyPrinted)
            req.httpBody = dat
        } catch let e {
            log("JSON Serialization error \(e)")
            return
        }
        dataTaskWithRequest(req as URLRequest, authenticated: true, retryCount: 0) { (dat, resp, _) in
            print("[PUSH] registered device token: \(reqJson)")
            let datString = String(data: dat ?? Data(), encoding: .utf8)
            self.log("save push token resp: \(resp?.statusCode ?? 0) data: \(String(describing: datString))")
            }.resume()
    }
    
    func deletePushNotificationToken(_ token: Data) {
        var req = URLRequest(url: url("/me/push-devices/apns/\(token.hexString)"))
        req.httpMethod = "DELETE"
        dataTaskWithRequest(req as URLRequest, authenticated: true, retryCount: 0) { (_, resp, _) in
            self.log("delete push token resp: \(String(describing: resp))")
            if let statusCode = resp?.statusCode {
                if statusCode >= 200 && statusCode < 300 {
                    UserDefaults.pushToken = nil
                    self.log("deleted old token")
                }
            }
            }.resume()
    }
}

private func pushNotificationEnvironment() -> String {
    return E.isDebug ? "d" : "p" //development or production
}
