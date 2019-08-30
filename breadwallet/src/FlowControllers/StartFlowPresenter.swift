//
//  StartFlowPresenter.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-22.
//  Copyright © 2016-2019 Breadwinner AG. All rights reserved.
//

import UIKit
import BRCrypto

typealias LoginCompletionHandler = ((Account) -> Void)

class StartFlowPresenter: Subscriber, Trackable {
    
    // MARK: - Properties
    
    private let rootViewController: RootNavigationController
    private var navigationController: ModalNavigationController?
    private let navigationControllerDelegate: StartNavigationDelegate
    private let keyMaster: KeyMaster
    private var loginViewController: UIViewController?
    private let loginTransitionDelegate = LoginTransitionDelegate()
    private var createHomeScreen: ((UINavigationController) -> HomeScreenViewController)
    private var createBuyScreen: (() -> BRWebViewController)?
    private var shouldBuyCoinAfterOnboarding: Bool = false
    private var onboardingCompletionHandler: LoginCompletionHandler?
    
    // MARK: - Public

    init(keyMaster: KeyMaster,
         rootViewController: RootNavigationController, 
         createHomeScreen: @escaping (UINavigationController) -> HomeScreenViewController,
         createBuyScreen: @escaping () -> BRWebViewController) {
        self.keyMaster = keyMaster
        self.rootViewController = rootViewController
        self.navigationControllerDelegate = StartNavigationDelegate()
        self.createHomeScreen = createHomeScreen
        self.createBuyScreen = createBuyScreen

        // no onboarding, make home screen visible after unlock
        if !keyMaster.noWallet {
            self.pushHomeScreen()
        }

        addSubscriptions()
    }
    
    /// Onboarding
    func startOnboarding(completion: @escaping LoginCompletionHandler) {
        onboardingCompletionHandler = completion
        
        /// Displays the onboarding screen (app landing page) that allows the user to either create
        /// a new wallet or restore an existing wallet.
        
        // Register the onboarding event context so that events are logged to the server throughout
        // the onboarding process, including post-walkthrough events such as PIN entry and paper-key entry.
        EventMonitor.shared.register(.onboarding)
        
        let onboardingScreen = OnboardingViewController(didExitOnboarding: { [weak self] (action) in
            guard let `self` = self else { return }
            
            switch action {
            case .restoreWallet:
                self.enterRecoverWalletFlow()
            case .createWallet:
                self.enterCreateWalletFlow()
            case .createWalletBuyCoin:
                // This will be checked in dismissStartFlow(), which is called after the PIN
                // and paper key flows are finished.
                self.shouldBuyCoinAfterOnboarding = true
                self.enterCreateWalletFlow()
            }
        })
        
        navigationController = ModalNavigationController(rootViewController: onboardingScreen)
        navigationController?.delegate = navigationControllerDelegate
        
        if let onboardingFlow = navigationController {
            onboardingFlow.setNavigationBarHidden(true, animated: false)
            
            // This will be set to true if the user exits onboarding with the `createWalletBuyCoin` action.
            shouldBuyCoinAfterOnboarding = false
            
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
            case .invalidSerialization:
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
                            callback: { self.handleLoginRequiredChange(state: $0)
        })
        Store.subscribe(self, name: .lock, callback: { _ in
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

    private func pushPinCreationViewForRecoveredWallet(recoveredAccount: Account) {
        var account = recoveredAccount
        let group = DispatchGroup()

        group.enter()
        keyMaster.fetchCreationDate(for: account) { updatedAccount in
            account = updatedAccount
            group.leave()
        }

        group.enter()
        let activity = BRActivityViewController(message: "")
        let pinCreationView = UpdatePinViewController(keyMaster: self.keyMaster,
                                                      type: .creationNoPhrase,
                                                      showsBackButton: false)
        pinCreationView.setPinSuccess = { _ in
            group.leave()
            pinCreationView.present(activity, animated: true)

        }
        self.navigationController?.pushViewController(pinCreationView, animated: true)

        group.notify(queue: DispatchQueue.main) {
            activity.dismiss(animated: true)
            self.onboardingCompletionHandler?(account)
            self.dismissStartFlow()
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
                UserDefaults.selectedCurrencyCode = nil // to land on home screen after new wallet creation //TODO:CRYPTO no longer used
                DispatchQueue.main.async {
                    self.pushStartPaperPhraseCreationViewController(pin: pin, eventContext: .onboarding)
                    self.onboardingCompletionHandler?(account)
                }
            }
        }

        navigationController?.setClearNavbar()
        navigationController?.setNavigationBarHidden(false, animated: false)
        navigationController?.pushViewController(pinCreationViewController, animated: true)
    }

    private func handleWalletCreationError() {
        let alert = UIAlertController(title: S.Alert.error, message: "Could not create wallet", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: S.Button.ok, style: .default, handler: nil))
        navigationController?.present(alert, animated: true, completion: nil)
    }
    
    private func pushStartPaperPhraseCreationViewController(pin: String, eventContext: EventContext = .none) {
        guard let navController = navigationController else { return }
        
        RecoveryKeyFlowController.enterRecoveryKeyFlow(pin: pin,
                                                       keyMaster: self.keyMaster,
                                                       from: navController,
                                                       context: eventContext,
                                                       dismissAction: dismissStartFlow,
                                                       modalPresentation: false,
                                                       canExit: false)
    }
    
    private func dismissStartFlow() {
        saveEvent(context: .onboarding, event: .complete)
        
        // Onboarding is finished.
        EventMonitor.shared.deregister(.onboarding)
        
        if self.shouldBuyCoinAfterOnboarding {
            self.presentPostOnboardingBuyScreen()
        } else {
            navigationController?.dismiss(animated: true) { [unowned self] in
                self.navigationController = nil
            }
        }
    }
    
    private func presentPostOnboardingBuyScreen() {
        guard let createBuyScreen = createBuyScreen else { return }
        
        let buyScreen = createBuyScreen()
        
        buyScreen.didClose = { [unowned self] in
            self.navigationController = nil
        }
        
        self.navigationController?.pushViewController(buyScreen, animated: true)
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
                                            keyMaster: keyMaster)
        loginView.transitioningDelegate = loginTransitionDelegate
        loginView.modalPresentationStyle = .overFullScreen
        loginView.modalPresentationCapturesStatusBarAppearance = true
        loginViewController = loginView
        if let modal = rootViewController.presentedViewController {
            modal.dismiss(animated: false, completion: {
                self.rootViewController.present(loginView, animated: false)
            })
        } else {
            rootViewController.present(loginView, animated: false)
        }
    }

    private func dismissLoginFlow() {
        loginViewController?.dismiss(animated: true, completion: { [weak self] in
            self?.loginViewController = nil
        })
    }
}
