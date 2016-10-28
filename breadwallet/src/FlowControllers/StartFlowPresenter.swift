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
    private var navigationController: UINavigationController?

    init(store: Store, rootViewController: UIViewController) {
        self.store = store
        self.rootViewController = rootViewController
        addStartSubscription()
        addPinCreationSubscription()
        addPaperPhraseCreationSubscription()
    }

    private func addStartSubscription() {
        store.subscribe(self, subscription: Subscription(
            selector: { $0.isStartFlowVisible != $1.isStartFlowVisible },
            callback: {
                if $0.isStartFlowVisible {
                    self.presentStartFlow()
                } else {
                    self.dismissStartFlow()
                }
            }))
    }

    private func addPinCreationSubscription() {
        store.subscribe(self, subscription: Subscription(
            selector: { $0.pinCreationStep != $1.pinCreationStep },
            callback: {
                if case .start = $0.pinCreationStep {
                    self.pushPinCreationViewController()
                }
        }))
    }

    private func addPaperPhraseCreationSubscription() {
        store.subscribe(self, subscription: Subscription(
            selector: { $0.paperPhraseStep != $1.paperPhraseStep },
            callback: {
                if case .start = $0.paperPhraseStep {
                    self.pushStartPaperPhraseCreationViewController()
                }

                if case .write = $0.paperPhraseStep {
                    self.pushWritePaperPhraseViewController()
                }

                if case .confirm = $0.paperPhraseStep {
                    self.pushConfirmPaperPhraseViewController()
                }
        }))
    }

    private func presentStartFlow() {
        let startViewController = StartViewController(store: store)
        navigationController = UINavigationController(rootViewController: startViewController)
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
        pinCreationViewController.title = "Create New Wallet"

        //Access the view as we want to trigger viewDidLoad before it gets pushed.
        //This makes the keyboard slide in from the right.
        let _ = pinCreationViewController.view
        navigationController?.setNavigationBarHidden(false, animated: false)
        setBackArrow()
        navigationController?.pushViewController(pinCreationViewController, animated: true)
    }

    private func pushStartPaperPhraseCreationViewController() {
        let paperPhraseViewController = StartPaperPhraseViewController(store: store)
        paperPhraseViewController.title = "Paper Key"
        paperPhraseViewController.navigationItem.setHidesBackButton(true, animated: false)
        navigationController?.pushViewController(paperPhraseViewController, animated: true)
    }

    private func pushWritePaperPhraseViewController() {
        let writeViewController = WritePaperPhraseViewController(store: store)
        writeViewController.title = "Paper Key"

        let button = UIButton.makeCloseButton()
        button.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        writeViewController.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: button)
        navigationController?.pushViewController(writeViewController, animated: true)
    }

    private func pushConfirmPaperPhraseViewController() {
        let confirmViewController = ConfirmPaperPhraseViewController(store: store)
        confirmViewController.title = "Paper Key"
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
}
