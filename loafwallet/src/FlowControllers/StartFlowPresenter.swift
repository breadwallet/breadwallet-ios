//
//  StartFlowPresenter.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-22.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

class StartFlowPresenter : Subscriber {

    //MARK: - Public
    init(store: Store, walletManager: WalletManager, rootViewController: UIViewController) {
        self.store = store
        self.walletManager = walletManager
        self.rootViewController = rootViewController
        self.navigationControllerDelegate = StartNavigationDelegate(store: store)
        addSubscriptions()
    }

    //MARK: - Private
    private let store: Store
    private let rootViewController: UIViewController
    private var navigationController: ModalNavigationController?
    private let navigationControllerDelegate: StartNavigationDelegate
    private let walletManager: WalletManager
    private var loginViewController: UIViewController?
    private let loginTransitionDelegate = LoginTransitionDelegate()

    private var closeButton: UIButton {
        let button = UIButton.close
        button.tintColor = .white
        button.tap = { [weak self] in
            self?.store.perform(action: HideStartFlow())
        }
        return button
    }

    private func addSubscriptions() {
        store.subscribe(self,
                        selector: { $0.isStartFlowVisible != $1.isStartFlowVisible },
                        callback: { self.handleStartFlowChange(state: $0) })
        store.lazySubscribe(self,
                        selector: { $0.isLoginRequired != $1.isLoginRequired },
                        callback: { self.handleLoginRequiredChange(state: $0) }) //TODO - this should probably be in modal presenter
        store.subscribe(self, name: .lock,
                        callback: { _ in self.presentLoginFlow(isPresentedForLock: true) })
    }

    private func handleStartFlowChange(state: State) {
        if state.isStartFlowVisible {
            guardProtected(queue: DispatchQueue.main) { [weak self] in
                self?.presentStartFlow()
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

    private func presentStartFlow() {
        let startViewController = StartViewController(store: store,
                                                      didTapCreate: { [weak self] in
            self?.pushPinCreationViewControllerForNewWallet()
        },
                                                      didTapRecover: { [weak self] in
            guard let myself = self else { return }
            let recoverIntro = RecoverWalletIntroViewController(didTapNext: myself.pushRecoverWalletView)
            myself.navigationController?.setTintableBackArrow()
            myself.navigationController?.setClearNavbar()
            myself.navigationController?.modalPresentationStyle = .fullScreen
            myself.navigationController?.setNavigationBarHidden(false, animated: false)
            myself.navigationController?.pushViewController(recoverIntro, animated: true)
        })

        navigationController = ModalNavigationController(rootViewController: startViewController)
        navigationController?.delegate = navigationControllerDelegate
        navigationController?.modalPresentationStyle = .fullScreen
        
        if let startFlow = navigationController {
            startFlow.setNavigationBarHidden(true, animated: false)
            rootViewController.present(startFlow, animated: false, completion: nil)
        }
    }

    private var pushRecoverWalletView: () -> Void {
        return { [weak self] in
            guard let myself = self else { return }
            let recoverWalletViewController = EnterPhraseViewController(store: myself.store, walletManager: myself.walletManager, reason: .setSeed(myself.pushPinCreationViewForRecoveredWallet))
            myself.navigationController?.pushViewController(recoverWalletViewController, animated: true)
        }
    }

    private func pushPinCreationViewControllerForNewWallet() {
        let pinCreationViewController = UpdatePinViewController(store: store, walletManager: walletManager, type: .creationNoPhrase, showsBackButton: true, phrase: nil)
        pinCreationViewController.setPinSuccess = { [weak self] pin in
            autoreleasepool {
                guard self?.walletManager.setRandomSeedPhrase() != nil else { self?.handleWalletCreationError(); return }
                self?.store.perform(action: WalletChange.setWalletCreationDate(Date()))
                DispatchQueue.walletQueue.async {
                    self?.walletManager.peerManager?.connect()
                    DispatchQueue.main.async {
                        self?.pushStartPaperPhraseCreationViewController(pin: pin)
                        self?.store.trigger(name: .didCreateOrRecoverWallet)
                    }
                }
            }
        }

        navigationController?.setNavigationBarHidden(false, animated: false)
        navigationController?.setTintableBackArrow()
        navigationController?.setClearNavbar()
        navigationController?.pushViewController(pinCreationViewController, animated: true)
    }
    
    private var pushPinCreationViewForRecoveredWallet: (String) -> Void {
        return { [weak self] phrase in
            guard let myself = self else { return }
            let pinCreationView = UpdatePinViewController(store: myself.store, walletManager: myself.walletManager, type: .creationWithPhrase, showsBackButton: false, phrase: phrase)
            pinCreationView.setPinSuccess = { [weak self] _ in
                DispatchQueue.walletQueue.async {
                    self?.walletManager.peerManager?.connect()
                    DispatchQueue.main.async {
                        self?.store.trigger(name: .didCreateOrRecoverWallet)
                    }
                }
            }
            myself.navigationController?.pushViewController(pinCreationView, animated: true)
        }
    }
    
    private func pushStartPaperPhraseCreationViewController(pin: String) {
        let paperPhraseViewController = StartPaperPhraseViewController(store: store, callback: { [weak self] in
            self?.pushWritePaperPhraseViewController(pin: pin)
        })
        paperPhraseViewController.title = S.SecurityCenter.Cells.paperKeyTitle
        paperPhraseViewController.navigationItem.setHidesBackButton(true, animated: false)
        paperPhraseViewController.hideCloseNavigationItem() //Forces user to confirm paper-key
  
        navigationController?.navigationBar.titleTextAttributes = [
            NSAttributedStringKey.foregroundColor: UIColor.white,
            NSAttributedStringKey.font: UIFont.customBold(size: 17.0)
        ]
        navigationController?.pushViewController(paperPhraseViewController, animated: true)
    }

    private func pushWritePaperPhraseViewController(pin: String) {
        let writeViewController = WritePaperPhraseViewController(store: store, walletManager: walletManager, pin: pin, callback: { [weak self] in
            self?.pushConfirmPaperPhraseViewController(pin: pin)
        })
        writeViewController.title = S.SecurityCenter.Cells.paperKeyTitle
        writeViewController.hideCloseNavigationItem()
        navigationController?.pushViewController(writeViewController, animated: true)
    }

    private func pushConfirmPaperPhraseViewController(pin: String) {
         
        let confirmVC = UIStoryboard.init(name: "Phrase", bundle: nil).instantiateViewController(withIdentifier: "ConfirmPaperPhraseViewController") as? ConfirmPaperPhraseViewController
            confirmVC?.store = self.store
            confirmVC?.walletManager = self.walletManager
            confirmVC?.pin = pin
            confirmVC?.didCompleteConfirmation = { [weak self] in
                guard let myself = self else { return }
                myself.store.perform(action: Alert.Show(.paperKeySet(callback: {
                    self?.store.perform(action: HideStartFlow())
                })))
            }
            navigationController?.navigationBar.tintColor = .white
        if let confirmVC = confirmVC {
            navigationController?.pushViewController(confirmVC, animated: true)
        }
    }

    private func presentLoginFlow(isPresentedForLock: Bool) {
        let loginView = LoginViewController(store: store, isPresentedForLock: isPresentedForLock, walletManager: walletManager)
        if isPresentedForLock {
            loginView.shouldSelfDismiss = true
        }
        loginView.transitioningDelegate = loginTransitionDelegate
        loginView.modalPresentationStyle = .overFullScreen
        loginView.modalPresentationCapturesStatusBarAppearance = true
        loginViewController = loginView
        rootViewController.present(loginView, animated: false, completion: nil)
    }
    
    private func handleWalletCreationError() {
        let alert = UIAlertController(title: S.Alert.error, message: "Could not create wallet", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: S.Button.ok, style: .default, handler: nil))
        navigationController?.present(alert, animated: true, completion: nil)
    }
    
    private func dismissStartFlow() {
        navigationController?.dismiss(animated: true) { [weak self] in
            self?.navigationController = nil
        }
    }

    private func dismissLoginFlow() {
        loginViewController?.dismiss(animated: true, completion: { [weak self] in
            self?.loginViewController = nil
        })
    }
}
