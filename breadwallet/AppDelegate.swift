//
//  AppDelegate.swift
//  breadwallet
//
//  Created by Aaron Voisine on 10/5/16.
//  Copyright (c) 2016-2019 Breadwinner AG. All rights reserved.
//

import UIKit
import LocalAuthentication
import CashUI
import CashCore

class AppDelegate: UIResponder, UIApplicationDelegate {

    private var window: UIWindow? {
        return applicationController.window
    }
    let applicationController = ApplicationController()
    
    static var url: EnvironmentUrl {
        #if TESTNET
        return .Staging
        #else
        return .Production
        #endif
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        redirectStdOut()
        UIView.swizzleSetFrame()
        applicationController.launch(application: application, options: launchOptions)
        CoreSessionManager.shared.start(url: AppDelegate.url)
        CoreSessionManager.shared.delegate = self
        NotificationCenter.default.addObserver(self, selector:#selector(handleSessionFailure), name: NSNotification.Name.CoreSessionDidFail, object: nil)
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        UIApplication.shared.applicationIconBadgeNumber = 0
        applicationController.didBecomeActive()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        applicationController.willEnterForeground()
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        applicationController.didEnterBackground()
    }

    func applicationWillResignActive(_ application: UIApplication) {
        applicationController.willResignActive()
    }

    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        applicationController.performFetch(completionHandler)
    }

    func application(_ application: UIApplication, shouldAllowExtensionPointIdentifier extensionPointIdentifier: UIApplication.ExtensionPointIdentifier) -> Bool {
        return false // disable extensions such as custom keyboards for security purposes
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        applicationController.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        applicationController.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return applicationController.open(url: url)
    }
    
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        return applicationController.application(application, continue: userActivity, restorationHandler: restorationHandler)
    }

    // stdout is redirected to C.logFilePath for testflight and debug builds
    private func redirectStdOut() {
        guard E.isTestFlight else { return }
        
        let logFilePath = C.logFilePath
        let previousLogFilePath = C.previousLogFilePath
        
        // If there is already content at C.logFilePath from the previous run of the app,
        // store that content in C.previousLogFilePath so that we can upload both the previous
        // and current log from Menu / Developer / Send Logs.
        if FileManager.default.fileExists(atPath: logFilePath.path) {
            // save the logging data from the previous run of the app
            if let logData = try? Data(contentsOf: C.logFilePath) {
                try? logData.write(to: previousLogFilePath, options: Data.WritingOptions.atomic)
            }
        }
        
        C.logFilePath.withUnsafeFileSystemRepresentation {
            _ = freopen($0, "w+", stdout)
        }
    }
}

extension AppDelegate: CoreSessionManagerDelegate {
    
    func sendCoin(amount: String, address: String, completion: @escaping (() -> Void)) {
        let applicationController = self.applicationController
        let modalPresenter = applicationController.modalPresenter
        
        let currencyId = Currencies.btc.uid
        modalPresenter!.presentModal(for: currencyId, amount: amount, address: address, completion: {
            completion()
        })
    }
    
}

extension AppDelegate {
    
    @objc func handleSessionFailure(_ notification: NSNotification) {
        let error = notification.object as! CashCoreError
        let alertController = UIAlertController(title: "Error", message: error.message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            
        })
        let root = window?.rootViewController as! RootNavigationController
        root.topViewController?.presentedViewController?.present(alertController, animated: true, completion: nil)
    }
}
