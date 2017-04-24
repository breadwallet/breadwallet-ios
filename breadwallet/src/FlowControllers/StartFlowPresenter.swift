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
        button.tap = {
            self.store.perform(action: HideStartFlow())
        }
        return button
    }

    private func addSubscriptions() {
        store.subscribe(self,
                        selector: { $0.isStartFlowVisible != $1.isStartFlowVisible },
                        callback: { self.handleStartFlowChange(state: $0) })
        store.subscribe(self,
                        selector: { $0.pinCreationStep != $1.pinCreationStep },
                        callback: { self.handlePinCreationStepChange(state: $0) })
        store.subscribe(self,
                        selector: { $0.paperPhraseStep != $1.paperPhraseStep },
                        callback: { self.handlePaperPhraseCreationChange(state: $0) })
        store.subscribe(self,
                        selector: { $0.isLoginRequired != $1.isLoginRequired },
                        callback: { self.handleLoginRequiredChange(state: $0) })
        store.subscribe(self, name: .lock, callback: { _ in
            self.presentLoginFlow(isPresentedForLock: true)
        })
    }

    private func handleStartFlowChange(state: State) {
        if state.isStartFlowVisible {
            presentStartFlow()
        } else {
            dismissStartFlow()
        }
    }

    private func handlePinCreationStepChange(state: State) {
        if case .start = state.pinCreationStep {
            pushPinCreationViewController()
        }
    }

    private func handlePaperPhraseCreationChange(state: State) {
        if case .start = state.paperPhraseStep {
            pushStartPaperPhraseCreationViewController()
        }

        if case .write = state.paperPhraseStep {
            if case .saveSuccess(let pin) = state.pinCreationStep {
                pushWritePaperPhraseViewController(pin: pin)
            }
        }

        if case .confirm = state.paperPhraseStep {
            if case .saveSuccess(let pin) = state.pinCreationStep {
                pushConfirmPaperPhraseViewController(pin: pin)
            }
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
        let startViewController = StartViewController(store: store, didTapRecover: { [weak self] in
            guard let myself = self else { return }
            let recoverIntro = RecoverWalletIntroViewController(didTapNext: myself.pushRecoverWalletView)
            myself.navigationController?.setTintableBackArrow()
            myself.navigationController?.setClearNavbar()
            myself.navigationController?.setNavigationBarHidden(false, animated: false)
            myself.navigationController?.pushViewController(recoverIntro, animated: true)
        })

        navigationController = ModalNavigationController(rootViewController: startViewController)
        navigationController?.delegate = navigationControllerDelegate
        if let startFlow = navigationController {
            startFlow.setNavigationBarHidden(true, animated: false)
            rootViewController.present(startFlow, animated: false, completion: nil)
        }
    }

    private var pushRecoverWalletView: () -> Void {
        return { [weak self] in
            guard let myself = self else { return }
            let recoverWalletViewController = RecoverWalletViewController(store: myself.store, walletManager: myself.walletManager)
            recoverWalletViewController.didSetSeedPhrase = myself.pushPinCreationView
            myself.navigationController?.pushViewController(recoverWalletViewController, animated: true)
        }
    }

    private var pushPinCreationView: (String) -> Void {
        return { [weak self] phrase in
            guard let myself = self else { return }
            let pinCreationView = UpdatePinViewController(store: myself.store, walletManager: myself.walletManager, phrase: phrase)
            pinCreationView.setPinSuccess = { [weak self] in
                DispatchQueue.walletQueue.async {
                    self?.walletManager.peerManager?.connect()
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

    private func pushPinCreationViewController() {
        let pinCreationViewController = PinCreationViewController(store: store)

        //Access the view as we want to trigger viewDidLoad before it gets pushed.
        //This makes the keyboard slide in from the right.
        let _ = pinCreationViewController.view
        navigationController?.setNavigationBarHidden(false, animated: false)
        navigationController?.setBlackBackArrow()
        navigationController?.setClearNavbar()
        navigationController?.pushViewController(pinCreationViewController, animated: true)
    }

    private func pushStartPaperPhraseCreationViewController() {
        let paperPhraseViewController = StartPaperPhraseViewController(store: store)
        paperPhraseViewController.title = "Paper Key"
        paperPhraseViewController.navigationItem.setHidesBackButton(true, animated: false)
        paperPhraseViewController.navigationItem.leftBarButtonItems = [UIBarButtonItem.negativePadding, UIBarButtonItem(customView: closeButton)]

        let faqButton = UIButton.buildFaqButton(store: store, articleId: ArticleIds.paperPhrase)
        faqButton.tintColor = .white
        paperPhraseViewController.navigationItem.rightBarButtonItems = [UIBarButtonItem.negativePadding, UIBarButtonItem(customView: faqButton)]

        navigationController?.navigationBar.titleTextAttributes = [
            NSForegroundColorAttributeName: UIColor.white,
            NSFontAttributeName: UIFont.customBold(size: 17.0)
        ]
        navigationController?.pushViewController(paperPhraseViewController, animated: true)
    }

    private func pushWritePaperPhraseViewController(pin: String) {
        //TODO - This is a pretty back hack. It's due to a limitation in the architecture, where the write state
        //will get triggered when the back button is pressed on the phrase confirm screen
        let writeViewInStack = (navigationController?.viewControllers.filter { $0 is WritePaperPhraseViewController}.count)! > 0
        guard !writeViewInStack else { return }

        let writeViewController = WritePaperPhraseViewController(store: store, walletManager: walletManager, pin: pin)
        writeViewController.title = "Paper Key"
        writeViewController.navigationItem.leftBarButtonItems = [UIBarButtonItem.negativePadding, UIBarButtonItem(customView: closeButton)]
        navigationController?.pushViewController(writeViewController, animated: true)
    }

    private func pushConfirmPaperPhraseViewController(pin: String) {
        let confirmViewController = ConfirmPaperPhraseViewController(store: store, walletManager: walletManager, pin: pin)
        confirmViewController.title = "Paper Key"
        navigationController?.navigationBar.tintColor = .white
        navigationController?.pushViewController(confirmViewController, animated: true)
    }

    private func presentLoginFlow(isPresentedForLock: Bool) {
        let loginView = LoginViewController(store: store, isPresentedForLock: isPresentedForLock, walletManager: walletManager)
        if isPresentedForLock {
            loginView.shouldSelfDismiss = true
        }
        loginView.transitioningDelegate = loginTransitionDelegate
        loginView.modalPresentationStyle = .overFullScreen
        loginViewController = loginView
        rootViewController.present(loginView, animated: false, completion: nil)
    }

    private func dismissLoginFlow() {
        loginViewController?.dismiss(animated: true, completion: {
            self.loginViewController = nil
        })
    }
}
