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
            presentLoginFlow()
        } else {
            dismissLoginFlow()
        }
    }

    private func presentStartFlow() {
        let startViewController = StartViewController(store: store, didTapRecover: {

            let recoverIntro = RecoverWalletIntroViewController() {
                let recoverWalletViewController = RecoverWalletViewController(store: self.store, walletManager: self.walletManager)
                self.navigationController?.pushViewController(recoverWalletViewController, animated: true)
            }

            self.navigationController?.setNavigationBarHidden(false, animated: false)
            self.navigationController?.setBackArrow()
            self.navigationController?.setClearNavbar()
            self.navigationController?.pushViewController(recoverIntro, animated: true)
        })

        navigationController = ModalNavigationController(rootViewController: startViewController)
        navigationController?.delegate = navigationControllerDelegate
        if let startFlow = navigationController {
            startFlow.setNavigationBarHidden(true, animated: false)
            rootViewController.present(startFlow, animated: false, completion: nil)
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
        navigationController?.setBackArrow()
        navigationController?.setClearNavbar()
        navigationController?.pushViewController(pinCreationViewController, animated: true)
    }

    private func pushStartPaperPhraseCreationViewController() {
        let paperPhraseViewController = StartPaperPhraseViewController(store: store)
        paperPhraseViewController.title = "Paper Key"
        paperPhraseViewController.navigationItem.setHidesBackButton(true, animated: false)

        let closeButton = UIButton.close
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        closeButton.tintColor = .white
        paperPhraseViewController.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: closeButton)

        let faqButton = UIButton.faq
        faqButton.addTarget(self, action: #selector(faqButtonTapped), for: .touchUpInside)
        faqButton.tintColor = .white
        paperPhraseViewController.navigationItem.rightBarButtonItem = UIBarButtonItem(customView: faqButton)

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

        let button = UIButton.close
        button.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        button.tintColor = .white
        writeViewController.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: button)
        navigationController?.pushViewController(writeViewController, animated: true)
    }

    private func pushConfirmPaperPhraseViewController(pin: String) {
        let confirmViewController = ConfirmPaperPhraseViewController(store: store, walletManager: walletManager, pin: pin)
        confirmViewController.title = "Paper Key"
        navigationController?.navigationBar.tintColor = .white
        navigationController?.pushViewController(confirmViewController, animated: true)
    }

    private func presentLoginFlow() {
        let loginView = LoginViewController(store: store, walletManager: walletManager)
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

    @objc private func closeButtonTapped() {
        store.perform(action: HideStartFlow())
    }

    @objc private func faqButtonTapped() {
        print("Faq button tapped")
    }
}
