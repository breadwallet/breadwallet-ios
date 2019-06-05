//
//  StartFlowPresenter.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-22.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

typealias StartFlowCallback = (() -> Void)

class StartFlowPresenter: Subscriber, Trackable {

    init(keyMaster: KeyMaster,
         rootViewController: RootNavigationController, 
         createHomeScreen: @escaping (UINavigationController) -> HomeScreenViewController,
         createBuyScreen: @escaping () -> BRWebViewController) {
        self.keyMaster = keyMaster
        self.rootViewController = rootViewController
        self.navigationControllerDelegate = StartNavigationDelegate()
        self.createHomeScreen = createHomeScreen
        self.createBuyScreen = createBuyScreen
        addSubscriptions()
    }

    // MARK: - Private
    private let rootViewController: RootNavigationController
    private var navigationController: ModalNavigationController?
    private let navigationControllerDelegate: StartNavigationDelegate
    private let keyMaster: KeyMaster
    private var loginViewController: UIViewController?
    private let loginTransitionDelegate = LoginTransitionDelegate()
    private var createHomeScreen: ((UINavigationController) -> HomeScreenViewController)
    private var createBuyScreen: (() -> BRWebViewController)?
    private var shouldBuyCoinAfterOnboarding: Bool = false
    
    private var closeButton: UIButton {
        let button = UIButton.close
        button.tintColor = .white
        button.tap = {
            Store.perform(action: HideStartFlow())
        }
        return button
    }

    private func addSubscriptions() {
        Store.lazySubscribe(self,
                        selector: { $0.isStartFlowVisible != $1.isStartFlowVisible },
                        callback: { self.handleStartFlowChange(state: $0) })
        Store.lazySubscribe(self,
                        selector: { $0.isLoginRequired != $1.isLoginRequired },
                        callback: { self.handleLoginRequiredChange(state: $0)
        })
        Store.subscribe(self, name: .lock, callback: { _ in
            self.presentLoginFlow(isPresentedForLock: true)
        })
    }

    private func handleStartFlowChange(state: State) {
        if state.isStartFlowVisible {
            guardProtected(queue: DispatchQueue.main) { [weak self] in
                self?.presentOnboardingFlow()
            }
        } else {
            dismissStartFlow()
        }
    }

    private func handleLoginRequiredChange(state: State) {
        if state.isLoginRequired {
            presentLoginFlow(isPresentedForLock: false)
        } else {
            dismissLoginFlow()
        }
    }

    private func enterRecoverWalletFlow() {

        navigationController?.setClearNavbar()
        navigationController?.setNavigationBarHidden(false, animated: false)
        
        let recoverWalletViewController =
            EnterPhraseViewController(keyMaster: self.keyMaster,
                                      reason: .setSeed(self.pushPinCreationViewForRecoveredWallet))
        
        self.navigationController?.pushViewController(recoverWalletViewController, animated: true)
    }

    // Displays the onboarding screen (app landing page) that allows the user to either create
    // a new wallet or restore an existing wallet. 
    private func presentOnboardingFlow() {
        
        // Register the onboarding event context so that events are logged to the server throughout
        // the onboarding process, including post-walkthrough events such as PIN entry and paper-key entry.
        EventMonitor.shared.register(.onboarding)
        
        let onboardingScreen = OnboardingViewController(didExitOnboarding: { [weak self] (action) in
            guard let `self` = self else { return }
            
            switch action {
            case .restoreWallet:
                self.enterRecoverWalletFlow()
            case .createWallet:
                self.enterCreateWalletFlow(eventContext: .onboarding)
            case .createWalletBuyCoin:
                // This will be checked in dismissStartFlow(), which is called after the PIN
                // and paper key flows are finished.
                self.shouldBuyCoinAfterOnboarding = true
                self.enterCreateWalletFlow(eventContext: .onboarding)
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
                let homeScreen = self.createHomeScreen(self.rootViewController)
                self.rootViewController.pushViewController(homeScreen, animated: false)
            }
        }
    }

    private var pushRecoverWalletView: () -> Void {
        return { [weak self] in
            guard let `self` = self else { return }
            let recoverWalletViewController =
                EnterPhraseViewController(keyMaster: self.keyMaster,
                                          reason: .setSeed(self.pushPinCreationViewForRecoveredWallet))
            self.navigationController?.pushViewController(recoverWalletViewController, animated: true)
        }
    }

    private var pushPinCreationViewForRecoveredWallet: (String) -> Void {
        return { [weak self] phrase in
            guard let `self` = self else { return }
            let pinCreationView = UpdatePinViewController(keyMaster: self.keyMaster, type: .creationWithPhrase, showsBackButton: false, phrase: phrase)
            pinCreationView.setPinSuccess = { _ in
                DispatchQueue.main.async {
                    Store.trigger(name: .didCreateOrRecoverWallet)
                }
            }
            self.navigationController?.pushViewController(pinCreationView, animated: true)
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
    
    private func enterCreateWalletFlow() {
        enterCreateWalletFlow(eventContext: .none)
    }
    
    private func enterCreateWalletFlow(eventContext: EventContext) {
        let pinCreationViewController = UpdatePinViewController(keyMaster: keyMaster,
                                                                type: .creationNoPhrase,
                                                                showsBackButton: true,
                                                                phrase: nil,
                                                                eventContext: eventContext)
        let context = eventContext
        
        pinCreationViewController.setPinSuccess = { [weak self] pin in
            autoreleasepool {
                guard self?.keyMaster.setRandomSeedPhrase() != nil else { self?.handleWalletCreationError(); return }
                //TODO:BCH multi-currency support
                UserDefaults.selectedCurrencyCode = nil // to land on home screen after new wallet creation
                Store.perform(action: WalletChange(Currencies.btc).setWalletCreationDate(Date()))
                DispatchQueue.main.async {
                    self?.pushStartPaperPhraseCreationViewController(pin: pin, eventContext: context)
                    Store.trigger(name: .didCreateOrRecoverWallet)
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
                                                       dismissAction: HideStartFlow(),
                                                       modalPresentation: false,
                                                       canExit: false)
    }

    private func presentLoginFlow(isPresentedForLock: Bool) {
        let loginView = LoginViewController(isPresentedForLock: isPresentedForLock, keyMaster: keyMaster)
        loginView.transitioningDelegate = loginTransitionDelegate
        loginView.modalPresentationStyle = .overFullScreen
        loginView.modalPresentationCapturesStatusBarAppearance = true
        loginViewController = loginView
        if let modal = rootViewController.presentedViewController {
            modal.dismiss(animated: false, completion: {
                self.rootViewController.present(loginView, animated: false, completion: nil)
            })
        } else {
            rootViewController.present(loginView, animated: false, completion: nil)
        }
    }

    private func dismissLoginFlow() {
        loginViewController?.dismiss(animated: true, completion: { [weak self] in
            self?.loginViewController = nil
        })
    }
}
