//
//  NotificationAuthorizer.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2018-07-16.
//  Copyright © 2018-2019 Breadwinner AG. All rights reserved.
//

import Foundation
import UserNotifications
import UIKit

// Handles user authorization for push notifications.
struct NotificationAuthorizer: Trackable {
    
    // When the user is initially prompted to opt into push notifications, they can defer the decision,
    // or proceed to the system notifications prompt and either allow or deny
    enum OptInPromptResponse {
        case deferred
        case allowed
        case denied
    }
    
    typealias AuthorizationHandler = (_ granted: Bool) -> Void
    typealias ShouldShowOptInCallback = (_ shouldShowOptIn: Bool) -> Void
    typealias OptInResponseCallback = (_ optInResponse: OptInPromptResponse) -> Void
    
    let options: UNAuthorizationOptions = [.alert, .sound, .badge]
    
    let nagUserLaunchCountInterval = 10          // nag the user every 10 launches if notifications were deferred
    let maxNagUserCountForNotificationsOptIn = 2 // initial plus nag twice => 3 total
    
    var optInDeferralCount: Int {
        return UserDefaults.notificationOptInDeferralCount
    }
    
    private func bumpOptInDeferralCount() {
        UserDefaults.notificationOptInDeferralCount += 1
    }
    
    var launchesSinceLastDeferral: Int {
        return UserDefaults.appLaunchCount - UserDefaults.appLaunchesAtLastNotificationDeferral
    }
    
    var haveEnoughLaunchesSinceLastDeferral: Bool {
        let launchesSinceLastDeferral = UserDefaults.appLaunchCount - UserDefaults.appLaunchesAtLastNotificationDeferral
        return launchesSinceLastDeferral >= nagUserLaunchCountInterval
    }
    
    var isOkToNagUserForOptIn: Bool {
        return UserDefaults.notificationOptInDeferralCount <= maxNagUserCountForNotificationsOptIn
    }
    
    func requestAuthorization(fromViewController viewController: UIViewController, completion: @escaping AuthorizationHandler) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .authorized, .provisional:
                    if !(settings.alertSetting == .enabled ||
                        settings.soundSetting == .enabled ||
                        settings.notificationCenterSetting == .enabled ||
                        settings.lockScreenSetting == .enabled ||
                        settings.badgeSetting == .enabled) {
                        self.showAlertForDisabledNotifications(fromViewController: viewController, completion: completion)
                    } else {
                        UIApplication.shared.registerForRemoteNotifications()
                        completion(true)
                    }
                case .notDetermined:
                    self.showAlertForInitialAuthorization(fromViewController: viewController, completion: completion)
                case .denied:
                    self.showAlertForDisabledNotifications(fromViewController: viewController, completion: completion)
                @unknown default:
                    assertionFailure("unknown notification auth status")
                    completion(false)
                }
            }
        }
    }
    
    func areNotificationsAuthorized(completion: @escaping AuthorizationHandler) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional:
                completion(true)
            case .notDetermined, .denied:
                completion(false)
            @unknown default:
                assertionFailure("unknown notification auth status")
                completion(false)
            }
        }
    }
    
    func checkShouldShowOptIn(completion: @escaping ShouldShowOptInCallback) {
        
        // Don't show the opt-in prompt on top of the login screen.
        guard !Store.state.isLoginRequired else {
            completion(false)
            return
        }
        
        // Don't show the opt-in prompt if we haven't had sufficent app launches since there
        // is already a lot going on when the user first creates or restores a wallet.
        guard UserDefaults.appLaunchCount > ApplicationController.initialLaunchCount else {
            completion(false)
            return
        }
        
        // First check if the user has already granted or denied push notifications.
        UNUserNotificationCenter.current().getNotificationSettings(completionHandler: { settings in

            switch settings.authorizationStatus {
            case .authorized, .denied, .provisional:
                completion(false)
                return
            default:
                break
            }            
            
            if self.optInDeferralCount == 0 {
                completion(true)
                return
            }
            
            if self.isOkToNagUserForOptIn && self.haveEnoughLaunchesSinceLastDeferral {
                completion(true)
                return
            }
            
            completion(false)
        })
    }
    
    func userDidDeferNotificationsOptIn() {
        // Keeping track of this count will be used to ensure we don't nag the user forever about notifications.
        bumpOptInDeferralCount()
        
        // Record the launch count at which the user deferred the opt-in so we can determine when
        // it's ok to show it again.
        UserDefaults.appLaunchesAtLastNotificationDeferral = UserDefaults.appLaunchCount
    }

    // Shows an alert dialog asking the user to opt into push notifications or defer making a decision.
    func showNotificationsOptInAlert(from viewController: UIViewController, callback: @escaping (Bool) -> Void) {
        
        // First check if it's ok to prompt the user.
        checkShouldShowOptIn(completion: { (shouldShow) in
            guard shouldShow else {
                callback(false)
                return
            }
            
            self.showOptInAlert(fromViewController: viewController, completion: { (response) in
                switch response {
                case .deferred:
                    self.userDidDeferNotificationsOptIn()
                case .denied:   break
                case .allowed:  break
                }
                
                callback(true)  // 'true' => showed the opt-in alert
            })
            
        })
    }
    
    private func showOptInAlert(fromViewController viewController: UIViewController, completion: @escaping OptInResponseCallback) {
        let alert = UIAlertController(title: S.PushNotifications.title,
                                      message: S.PushNotifications.body,
                                      preferredStyle: .alert)
        
        let enableAction = UIAlertAction(title: S.Button.ok, style: .default) { _ in
            
            self.logEvent(.optInPrompt, .okButton)
            
            UNUserNotificationCenter.current().requestAuthorization(options: self.options) { (granted, _) in
                DispatchQueue.main.async {
                    if granted {
                        UIApplication.shared.registerForRemoteNotifications()
                        self.logEvent(.systemPrompt, .allowButton)
                        completion(.allowed)
                    } else {
                        self.logEvent(.systemPrompt, .denyButton)
                        completion(.denied)
                    }
                }
            }
        }
        
        let deferAction = UIAlertAction(title: S.Button.maybeLater, style: .cancel) { _ in
            // Logging this here rather than in `userDidDeferNotificationsOptIn()` so that it's not logged
            // during unit testing; however, at this point 'optInDeferralCount' won't be updated yet, so
            // add 1 when logging the event.
            self.logEvent(.optInPrompt, .deferButton, [ "count": String(self.optInDeferralCount + 1) ])
            completion(.deferred)
        }
        
        alert.addAction(enableAction)
        alert.addAction(deferAction)
        
        DispatchQueue.main.async {
            viewController.present(alert, animated: true, completion: nil)
        }
    }
    
    private func showAlertForInitialAuthorization(fromViewController viewController: UIViewController,
                                                  completion: @escaping AuthorizationHandler) {
        
        showOptInAlert(fromViewController: viewController, completion: { (response) in
            switch response {
            case .deferred, .denied:
                completion(false)
            case .allowed:
                completion(true)
            }
        })
    }

    private func showAlertForDisabledNotifications(fromViewController viewController: UIViewController, completion: @escaping AuthorizationHandler) {
        let alert = UIAlertController(title: S.PushNotifications.disabled,
                                      message: S.PushNotifications.enableInstructions,
                                      preferredStyle: .alert)
        
        let settingsAction = UIAlertAction(title: S.Button.settings, style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
            completion(false)
        }
        let cancelAction = UIAlertAction(title: S.Button.cancel, style: .cancel) { _ in
            completion(false)
        }
        
        alert.addAction(settingsAction)
        alert.addAction(cancelAction)
        viewController.present(alert, animated: true, completion: nil)
    }
    
    func logEvent(_ screen: Screen, _ event: Event, _ attributes: [String: String]? = nil) {
        let eventName = makeEventName([EventContext.pushNotifications.name, screen.name, event.name])
        
        if let attr = attributes {
            saveEvent(eventName, attributes: attr)
        } else {
            saveEvent(eventName)
        }
    }
}
