//
//  NotificationAuthorizer.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2018-07-16.
//  Copyright © 2018 breadwallet LLC. All rights reserved.
//

import Foundation
import UserNotifications
import UIKit

struct NotificationAuthorizer: Trackable {
    
    typealias AuthorizationHandler = (_ granted: Bool) -> Void
    
    let options: UNAuthorizationOptions = [.alert, .sound, .badge]
    
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
            }
        }
    }
    
    private func showAlertForInitialAuthorization(fromViewController viewController:
        UIViewController, completion: @escaping AuthorizationHandler) {
        let alert = UIAlertController(title: S.PushNotifications.title,
                                      message: S.PushNotifications.body,
                                      preferredStyle: .alert)
        
        let enableAction = UIAlertAction(title: S.Button.ok, style: .default) { _ in
            UNUserNotificationCenter.current().requestAuthorization(options: self.options) { (granted, error) in
                DispatchQueue.main.async {
                    if granted {
                        UIApplication.shared.registerForRemoteNotifications()
                    } else {
                        self.saveEvent("push.systemPromptDenied")
                    }
                    completion(granted)
                }
            }
        }
        let cancelAction = UIAlertAction(title: S.Button.cancel, style: .cancel) { _ in
            self.saveEvent("push.firstPromptDenied")
            completion(false)
        }
        
        alert.addAction(enableAction)
        alert.addAction(cancelAction)
        viewController.present(alert, animated: true, completion: nil)
    }
    
    private func showAlertForDisabledNotifications(fromViewController viewController:
        UIViewController, completion: @escaping AuthorizationHandler) {
        let alert = UIAlertController(title: S.PushNotifications.disabled,
                                      message: S.PushNotifications.enableInstructions,
                                      preferredStyle: .alert)
        
        let settingsAction = UIAlertAction(title: S.Button.settings, style: .default) { _ in
            if let url = URL(string: UIApplicationOpenSettingsURLString) {
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
}
