//
//  StartFlowPresenter.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-22.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

class StartFlowPresenter: Subscriber {

    private let store: Store
    private let rootViewController: UIViewController
    private var navigationController: ModalNavigationController?
    private let navigationControllerDelegate: StartNavigationDelegate
    private let walletManager: WalletManager

    init(store: Store, walletManager: WalletManager, rootViewController: UIViewController) {
        self.store = store
        self.walletManager = walletManager
        self.rootViewController = rootViewController
        self.navigationControllerDelegate = StartNavigationDelegate(store: store)
        addStartSubscription()
        addPinCreationSubscription()
        addPaperPhraseCreationSubscription()
    }

    private func addStartSubscription() {
        store.subscribe(self,
            selector: { $0.isStartFlowVisible != $1.isStartFlowVisible },
            callback: {
                if $0.isStartFlowVisible {
                    self.presentStartFlow()
                } else {
                    self.dismissStartFlow()
                }
            })
    }

    private func addPinCreationSubscription() {
        store.subscribe(self,
            selector: { $0.pinCreationStep != $1.pinCreationStep },
            callback: {
                if case .start = $0.pinCreationStep {
                    self.pushPinCreationViewController()
                }
        })
    }

    private func addPaperPhraseCreationSubscription() {
        store.subscribe(self,
                        selector: { $0.paperPhraseStep != $1.paperPhraseStep },
                        callback: {
                            if case .start = $0.paperPhraseStep {
                                self.pushStartPaperPhraseCreationViewController()
                            }

                            if case .write = $0.paperPhraseStep {
                                if case .saveSuccess(let pin) = $0.pinCreationStep {
                                    self.pushWritePaperPhraseViewController(pin: pin)
                                }
                            }

                            if case .confirm = $0.paperPhraseStep {
                                if case .saveSuccess(let pin) = $0.pinCreationStep {
                                    self.pushConfirmPaperPhraseViewController(pin: pin)
                                }
                            }
                        })
    }

    private func presentStartFlow() {
        let startViewController = StartViewController(store: store)
        startViewController.recoverCallback = { phrase in
            //TODO - add more validation here
            let components = phrase.components(separatedBy: " ")
            if components.count != 12 {
                return false
            }
            if self.walletManager.setSeedPhrase(phrase) {
                self.store.perform(action: HideStartFlow())
                DispatchQueue.global(qos: .background).async {
                    self.walletManager.peerManager?.connect()
                }
                return true
            } else {
                return false
            }
        }

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
        setBackArrow()
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

    private func setBackArrow() {
        let image = #imageLiteral(resourceName: "Back")
        let renderedImage = image.withRenderingMode(.alwaysOriginal)
        navigationController?.navigationBar.backIndicatorImage = renderedImage
        navigationController?.navigationBar.backIndicatorTransitionMaskImage = renderedImage
    }

    @objc private func closeButtonTapped() {
        store.perform(action: HideStartFlow())
    }

    @objc private func faqButtonTapped() {
        print("Faq button tapped")
    }
}
