//
//  StartFlowPresenter.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-22.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

class StartFlowPresenter: Subscriber {

    // MARK: - Public
    init(walletManager: BTCWalletManager, rootViewController: RootNavigationController) {
        self.walletManager = walletManager
        self.rootViewController = rootViewController
        self.navigationControllerDelegate = StartNavigationDelegate()
        addSubscriptions()
    }

    // MARK: - Private
    private let rootViewController: RootNavigationController
    private var navigationController: ModalNavigationController?
    private let navigationControllerDelegate: StartNavigationDelegate
    private let walletManager: BTCWalletManager
    private var loginViewController: UIViewController?
    private let loginTransitionDelegate = LoginTransitionDelegate()

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
        let startViewController = StartViewController(didTapCreate: { [weak self] in
                                                        self?.pushPinCreationViewControllerForNewWallet()
        },
                                                      didTapRecover: { [weak self] in
            guard let myself = self else { return }
            let recoverIntro = RecoverWalletIntroViewController(didTapNext: myself.pushRecoverWalletView)
            myself.navigationController?.setClearNavbar()
            myself.navigationController?.setNavigationBarHidden(false, animated: false)
            myself.navigationController?.pushViewController(recoverIntro, animated: true)
        })

        navigationController = ModalNavigationController(rootViewController: startViewController)
        navigationController?.delegate = navigationControllerDelegate
        if let startFlow = navigationController {
            rootViewController.popToRootViewController(animated: false)
            startFlow.setNavigationBarHidden(true, animated: false)
            rootViewController.present(startFlow, animated: false, completion: nil)
        }
    }

    private var pushRecoverWalletView: () -> Void {
        return { [weak self] in
            guard let myself = self else { return }
            let recoverWalletViewController =
                EnterPhraseViewController(walletManager: myself.walletManager,
                                          reason: .setSeed(myself.pushPinCreationViewForRecoveredWallet))
            myself.navigationController?.pushViewController(recoverWalletViewController, animated: true)
        }
    }

    private var pushPinCreationViewForRecoveredWallet: (String) -> Void {
        return { [weak self] phrase in
            guard let myself = self else { return }
            let pinCreationView = UpdatePinViewController(walletManager: myself.walletManager, type: .creationWithPhrase, showsBackButton: false, phrase: phrase)
            pinCreationView.setPinSuccess = { _ in
                DispatchQueue.main.async {
                    Store.trigger(name: .didCreateOrRecoverWallet)
                }
            }
            myself.navigationController?.pushViewController(pinCreationView, animated: true)
        }
    }

    private func dismissStartFlow() {
        navigationController?.dismiss(animated: true) { [weak self] in
            self?.navigationController = nil
        }
    }

    private func pushPinCreationViewControllerForNewWallet() {
        let pinCreationViewController = UpdatePinViewController(walletManager: walletManager, type: .creationNoPhrase, showsBackButton: true, phrase: nil)
        pinCreationViewController.setPinSuccess = { [weak self] pin in
            autoreleasepool {
                guard self?.walletManager.setRandomSeedPhrase() != nil else { self?.handleWalletCreationError(); return }
                //TODO:BCH multi-currency support
                UserDefaults.selectedCurrencyCode = nil // to land on home screen after new wallet creation
                Store.perform(action: WalletChange(Currencies.btc).setWalletCreationDate(Date()))
                DispatchQueue.main.async {
                    self?.pushStartPaperPhraseCreationViewController(pin: pin)
                    Store.trigger(name: .didCreateOrRecoverWallet)
                }
            }
        }

        navigationController?.setNavigationBarHidden(false, animated: false)
        navigationController?.setClearNavbar()
        navigationController?.pushViewController(pinCreationViewController, animated: true)
    }

    private func handleWalletCreationError() {
        let alert = UIAlertController(title: S.Alert.error, message: "Could not create wallet", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: S.Button.ok, style: .default, handler: nil))
        navigationController?.present(alert, animated: true, completion: nil)
    }

    private func pushStartPaperPhraseCreationViewController(pin: String) {
        let paperPhraseViewController = StartPaperPhraseViewController(callback: { [weak self] in
            self?.pushWritePaperPhraseViewController(pin: pin)
        })
        paperPhraseViewController.title = S.SecurityCenter.Cells.paperKeyTitle
        paperPhraseViewController.navigationItem.setHidesBackButton(true, animated: false)
        paperPhraseViewController.navigationItem.leftBarButtonItems = [UIBarButtonItem.negativePadding, UIBarButtonItem(customView: closeButton)]

        let faqButton = UIButton.buildFaqButton(articleId: ArticleIds.paperKey)
        faqButton.tintColor = .white
        paperPhraseViewController.navigationItem.rightBarButtonItems = [UIBarButtonItem.negativePadding, UIBarButtonItem(customView: faqButton)]

        navigationController?.navigationBar.titleTextAttributes = [
            NSAttributedStringKey.foregroundColor: UIColor.white,
            NSAttributedStringKey.font: UIFont.customBold(size: 17.0)
        ]
        navigationController?.pushViewController(paperPhraseViewController, animated: true)
    }

    private func pushWritePaperPhraseViewController(pin: String) {
        let writeViewController = WritePaperPhraseViewController(walletManager: walletManager, pin: pin, callback: { [weak self] in
            self?.pushConfirmPaperPhraseViewController(pin: pin)
        })
        writeViewController.title = S.SecurityCenter.Cells.paperKeyTitle
        writeViewController.navigationItem.leftBarButtonItems = [UIBarButtonItem.negativePadding, UIBarButtonItem(customView: closeButton)]
        navigationController?.pushViewController(writeViewController, animated: true)
    }

    private func pushConfirmPaperPhraseViewController(pin: String) {
        let confirmViewController = ConfirmPaperPhraseViewController(walletManager: walletManager, pin: pin, callback: {
            Store.perform(action: Alert.Show(.paperKeySet(callback: {
                Store.perform(action: HideStartFlow())
            })))
        })
        confirmViewController.title = S.SecurityCenter.Cells.paperKeyTitle
        navigationController?.navigationBar.tintColor = .white
        navigationController?.pushViewController(confirmViewController, animated: true)
    }

    private func presentLoginFlow(isPresentedForLock: Bool) {
        let loginView = LoginViewController(isPresentedForLock: isPresentedForLock, walletManager: walletManager)
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
