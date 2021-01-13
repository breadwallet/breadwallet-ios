//
//  StartFlowPresenter.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-22.
//  Copyright © 2016-2019 Breadwinner AG. All rights reserved.
//

import UIKit
import WalletKit
import SwiftUI

typealias LoginCompletionHandler = ((Account) -> Void)

class StartFlowPresenter: Subscriber, Trackable {
    
    // MARK: - Properties
    
    private let rootViewController: RootNavigationController
    private var navigationController: ModalNavigationController?
    private let navigationControllerDelegate: StartNavigationDelegate
    private let keyMaster: KeyStore
    private var loginViewController: UIViewController?
    private let loginTransitionDelegate = LoginTransitionDelegate()
    private var createHomeScreen: ((UINavigationController) -> HomeScreenViewController)
    private var onboardingCompletionHandler: LoginCompletionHandler?
    private let shouldDisableBiometrics: Bool
    private var startupScreen: StartupScreen? = StartupScreen()
    
    // MARK: - Public

    init(keyMaster: KeyStore,
         rootViewController: RootNavigationController,
         shouldDisableBiometrics: Bool,
         createHomeScreen: @escaping (UINavigationController) -> HomeScreenViewController) {
        self.keyMaster = keyMaster
        self.rootViewController = rootViewController
        self.navigationControllerDelegate = StartNavigationDelegate()
        self.createHomeScreen = createHomeScreen
        self.shouldDisableBiometrics = shouldDisableBiometrics
        
        // no onboarding, make home screen visible after unlock
        if !keyMaster.noWallet {
            self.pushHomeScreen()
            
            if Store.state.isLoginRequired {
                self.pushStartupScreen()
            }
        }

        addSubscriptions()
    }
    
    deinit {
        Store.unsubscribe(self)
    }
    
    private func pushStartupScreen() {
        guard let startupScreen = self.startupScreen else { return }
        rootViewController.pushViewController(startupScreen, animated: false)
    }
    
    private func popStartupScreen() {
        rootViewController.popViewController(animated: false)
        DispatchQueue.main.async { [weak self] in
            self?.startupScreen = nil
        }
    }
    
    /// Onboarding
    func startOnboarding(completion: @escaping LoginCompletionHandler) {
        onboardingCompletionHandler = completion
        
        /// Displays the onboarding screen (app landing page) that allows the user to either create
        /// a new wallet or restore an existing wallet.
        
        // Register the onboarding event context so that events are logged to the server throughout
        // the onboarding process, including post-walkthrough events such as PIN entry and paper-key entry.
        EventMonitor.shared.register(.onboarding)
        
        let onboardingScreen = OnboardingViewController(doesCloudBackupExist: keyMaster.doesCloudBackupExist(),
                                                        didExitOnboarding: { [weak self] (action) in
            guard let `self` = self else { return }
            
            switch action {
            case .restoreWallet:
                self.enterRecoverWalletFlow()
            case .createWallet:
                self.enterCreateWalletFlow()
            case .restoreCloudBackup:
                self.enterRecoverCloudBackup()
            }
        })
        
        navigationController = ModalNavigationController(rootViewController: onboardingScreen)
        navigationController?.delegate = navigationControllerDelegate
        
        if let onboardingFlow = navigationController {
            onboardingFlow.modalPresentationStyle = .fullScreen
            onboardingFlow.setNavigationBarHidden(true, animated: false)
            
            rootViewController.present(onboardingFlow, animated: false) {
                
                // Stuff the home screen in as the root view controller so that when
                // the onboarding flow is finished, the home screen will be present. If
                // we push it before the present() call you can briefly see the home screen
                // before the onboarding screen is displayed -- not good.
                self.pushHomeScreen()
            }
        }
    }
    
    /// Initial unlock
    func startLogin(completion: @escaping LoginCompletionHandler) {
        assert(!keyMaster.noWallet && Store.state.isLoginRequired)
        
        switch keyMaster.loadAccount() {
        case .success(let account):
            // account was loaded without requiring authentication
            // call completion immediately start the system in the background
            presentLoginFlow(for: .automaticLock)
            completion(account)
            
        case .failure(let error):
            switch error {
            case .invalidSerialization, .disabled:
                // account needs to be recreated from seed so we must authenticate first
                presentLoginFlow(for: .initialLaunch(loginHandler: completion))
            default:
                assertionFailure("unexpected account error")
            }
        }
    }
    
    // MARK: - Private
    
    private func addSubscriptions() {
        Store.lazySubscribe(self,
                            selector: { $0.isLoginRequired != $1.isLoginRequired },
                            callback: { [unowned self] in
                                self.handleLoginRequiredChange(state: $0)
        })
        Store.subscribe(self, name: .lock, callback: { [unowned self] _ in
            self.presentLoginFlow(for: .manualLock)
        })
    }
    
    private func pushHomeScreen() {
        let homeScreen = self.createHomeScreen(self.rootViewController)
        self.rootViewController.pushViewController(homeScreen, animated: false)
    }
    
    // MARK: - Onboarding
    
    // MARK: Recover Wallet
    
    private func enterRecoverWalletFlow() {
        
        navigationController?.setClearNavbar()
        navigationController?.setNavigationBarHidden(false, animated: false)
        
        let recoverWalletViewController =
            EnterPhraseViewController(keyMaster: self.keyMaster,
                                      reason: .setSeed(self.pushPinCreationViewForRecoveredWallet))
        
        self.navigationController?.pushViewController(recoverWalletViewController, animated: true)
    }
    
    private func enterRecoverCloudBackup() {
        guard #available(iOS 13.6, *) else { return }
        let backups = keyMaster.listBackups()
        if backups.count > 1 {
            let selectView = SelectBackupView(backups: backups) {
                guard case let .success(backup) = $0 else {
                    self.navigationController?.popToRootViewController(animated: true)
                    return
                }
                self.recoverBackup(backup)
            }
            navigationController?.setClearNavbar()
            navigationController?.setNavigationBarHidden(false, animated: false)
            let vc = LightStatusBarHost(rootView: selectView)
            navigationController?.pushViewController(vc, animated: true)
        } else {
            recoverBackup(backups.first!)
        }
    }
    
    @available(iOS 13.6, *)
    private func recoverBackup(_ backup: CloudBackup) {
        let update = UpdatePinViewController(keyMaster: self.keyMaster,
                                             type: .recoverBackup,
                                             showsBackButton: true,
                                             phrase: nil,
                                             eventContext: .recoverCloud,
                                             backupKey: backup.identifier)
        update.didRecoverAccount = { [weak self] account in
            self?.handleRecoveredAccount(account)
        }
        navigationController?.setClearNavbar()
        navigationController?.setNavigationBarHidden(false, animated: false)
        navigationController?.pushViewController(update, animated: true)
    }
    
    private func handleRecoveredAccount(_ recoveredAccount: Account) {
        var account = recoveredAccount
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.keyMaster.fetchCreationDate(for: account) { updatedAccount in
                account = updatedAccount
                DispatchQueue.main.async {
                    self?.onboardingCompletionHandler?(account)
                }
            }
        }
        Store.perform(action: Alert.Show(.cloudBackupRestoreSuccess(callback: { [weak self] in
            self?.navigationController?.dismiss(animated: true) {
                self?.navigationController = nil
            }
        })))
    }

    private func pushPinCreationViewForRecoveredWallet(recoveredAccount: Account) {
        var account = recoveredAccount
        let group = DispatchGroup()

        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            self.keyMaster.fetchCreationDate(for: account) { updatedAccount in
                account = updatedAccount
                group.leave()
            }
        }

        group.enter()
        let activity = BRActivityViewController(message: "")
        let pinCreationView = UpdatePinViewController(keyMaster: self.keyMaster,
                                                      type: .creationNoPhrase,
                                                      showsBackButton: false)
        pinCreationView.setPinSuccess = { _ in
            pinCreationView.present(activity, animated: true)
            group.leave()
        }
        navigationController?.pushViewController(pinCreationView, animated: true)

        group.notify(queue: DispatchQueue.main) {
            self.onboardingCompletionHandler?(account)
            activity.dismiss(animated: true) {
                self.dismissStartFlow()
            }
        }
    }
    
    // MARK: Create Wallet

    private func enterCreateWalletFlow() {
        let pinCreationViewController = UpdatePinViewController(keyMaster: keyMaster,
                                                                type: .creationNoPhrase,
                                                                showsBackButton: false,
                                                                phrase: nil,
                                                                eventContext: .onboarding)
        pinCreationViewController.setPinSuccess = { [unowned self] pin in
            autoreleasepool {
                guard let (_, account) = self.keyMaster.setRandomSeedPhrase() else { self.handleWalletCreationError(); return }
                DispatchQueue.main.async {
                    self.enterCloudBackup(pin: pin, callback: {
                          self.pushStartPaperPhraseCreationViewController(pin: pin, eventContext: .onboarding)
                          self.onboardingCompletionHandler?(account)
                    })
                }
            }
        }

        navigationController?.setClearNavbar()
        navigationController?.setNavigationBarHidden(false, animated: false)
        navigationController?.pushViewController(pinCreationViewController, animated: true)
    }
    
    private func enterCloudBackup(pin: String, callback: @escaping () -> Void) {
        guard #available(iOS 13.6, *) else { callback(); return }
        //We don't need to show the backup view if backup is already on
        guard !keyMaster.doesCloudBackupExist() else { callback(); return }
        guard let navController = navigationController else { return }
        let synchronizer = BackupSynchronizer(context: .onboarding,
                                              keyStore: self.keyMaster,
                                              navController: navController)
        synchronizer.completion = callback
        let cloudView = CloudBackupView(synchronizer: synchronizer)
        let hosting = LightStatusBarHost(rootView: cloudView)
        navigationController?.pushViewController(hosting, animated: true)
    }

    private func handleWalletCreationError() {
        let alert = UIAlertController(title: S.Alert.error, message: "Could not create wallet", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: S.Button.ok, style: .default, handler: nil))
        navigationController?.present(alert, animated: true, completion: nil)
    }
    
    private func pushStartPaperPhraseCreationViewController(pin: String, eventContext: EventContext = .none) {
        guard let navController = navigationController else { return }
        
        let dismissAction: (() -> Void) = { [weak self] in
            self?.dismissStartFlow()
        }
        
        RecoveryKeyFlowController.enterRecoveryKeyFlow(pin: pin,
                                                       keyMaster: self.keyMaster,
                                                       from: navController,
                                                       context: eventContext,
                                                       dismissAction: dismissAction,
                                                       modalPresentation: false,
                                                       canExit: false)
    }
    
    private func dismissStartFlow() {
        guard let navigationController = navigationController else { return assertionFailure() }
        saveEvent(context: .onboarding, event: .complete)
        
        // Onboarding is finished.
        EventMonitor.shared.deregister(.onboarding)
        navigationController.dismiss(animated: true) { [unowned self] in
            self.navigationController = nil
        }
    }
    
    // MARK: - Login
    
    private func handleLoginRequiredChange(state: State) {
        if state.isLoginRequired {
            presentLoginFlow(for: .automaticLock)
        } else {
            dismissLoginFlow()
        }
    }

    private func presentLoginFlow(for context: LoginViewController.Context) {
        let loginView = LoginViewController(for: context,
                                            keyMaster: keyMaster,
                                            shouldDisableBiometrics: shouldDisableBiometrics)
        loginView.transitioningDelegate = loginTransitionDelegate
        loginView.modalPresentationStyle = .overFullScreen
        loginView.modalPresentationCapturesStatusBarAppearance = true
        loginViewController = loginView
        
        if let modal = rootViewController.presentedViewController {
            modal.dismiss(animated: false, completion: { [weak self] in
                guard let `self` = self else { return }
                self.rootViewController.present(loginView, animated: false, completion: {
                    self.popStartupScreen()
                })
            })
        } else {
            rootViewController.present(loginView, animated: false, completion: { [weak self] in
                guard let `self` = self else { return }
                self.popStartupScreen()
            })
        }
    }

    private func dismissLoginFlow() {
        guard let loginViewController = loginViewController, loginViewController.isBeingPresented else {
            self.loginViewController = nil
            return
        }
        loginViewController.dismiss(animated: true, completion: { [weak self] in
            self?.loginViewController = nil
        })
    }
}

// This is displayed over the home screen before the login screen is pushed.
private class StartupScreen: UIViewController {
    
    private var logo = UIImageView(image: #imageLiteral(resourceName: "LogoCutout").withRenderingMode(.alwaysTemplate))
    private var logoBackground = MotionGradientView()
    
    override var preferredStatusBarStyle: UIStatusBarStyle { return .lightContent }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = Theme.primaryBackground
        logo.tintColor = Theme.primaryBackground
        
        logoBackground.addSubview(logo)
        view.addSubview(logoBackground)
        
        logoBackground.constrain([
            logoBackground.topAnchor.constraint(equalTo: view.topAnchor,
                                                constant: C.Sizes.brdLogoHeight + C.Sizes.brdLogoTopMargin),
            logoBackground.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoBackground.heightAnchor.constraint(equalTo: logoBackground.widthAnchor,
                                                   multiplier: logo.image!.size.height/logo.image!.size.width),
            logoBackground.widthAnchor.constraint(equalTo: view.widthAnchor,
                                                  multiplier: 0.45) ])
        
        logo.constrain(toSuperviewEdges: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.shadowImage = UIImage()
        navigationController?.isNavigationBarHidden = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.isNavigationBarHidden = false
    }
}
