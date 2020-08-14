// 
//  BackupSynchronizer.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2020-08-07.
//  Copyright © 2020 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import Foundation
import UIKit

enum BackupContext {
    case onboarding
    case existingWallet
}

@available(iOS 13.6, *)
class BackupSynchronizer {
    
    private let keyStore: KeyStore
    private let navController: UINavigationController
    let context: BackupContext
    var completion: (() -> Void)?
    
    init(context: BackupContext, keyStore: KeyStore, navController: UINavigationController) {
        self.context = context
        self.keyStore = keyStore
        self.navController = navController
    }
    
    var isBackedUp: Bool {
        return keyStore.doesCurrentWalletHaveBackup()
    }
    
    func deleteBackup() {
        keyStore.deleteCurrentBackup()
    }
    
    func enableBackup(callback: @escaping (Bool) -> Void) {
        if context == .onboarding {
            enableBackupForOnboarding(callback: callback)
        } else {
            enableBackupForExisting(callback: callback)
        }
    }
    
    func skipBackup() {
        completion?()
    }
    
    private func enableBackupForOnboarding(callback: @escaping (Bool) -> Void) {
        callback(keyStore.addBackup())
        completion?()
    }
    
    private func enableBackupForExisting(callback: @escaping (Bool) -> Void) {
        let pinSuccess: (String) -> Void = { pin in
            if self.keyStore.addBackup(forPin: pin) {
                Store.perform(action: Alert.Show(.cloudBackupSuccess))
                callback(true)
            } else {
                callback(false)
            }
        }
        let pinViewController = VerifyPinViewController(bodyText: S.CloudBackup.encryptBackupMessage,
                                          pinLength: 6, //force backups to be 6 digit
                                          walletAuthenticator: self.keyStore,
                                          pinAuthenticationType: .transactions,
                                          success: pinSuccess)
        pinViewController.transitioningDelegate = RecoveryKeyFlowController.pinTransitionDelegate
        pinViewController.modalPresentationStyle = .overFullScreen
        pinViewController.modalPresentationCapturesStatusBarAppearance = true
        pinViewController.didCancel = {
            callback(false)
        }
        navController.present(pinViewController, animated: true, completion: nil)
    }
    
}
