//
//  StartFlowController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-22.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

class StartFlowController: Subscriber {

    private let store: Store
    private let rootViewController: UIViewController
    private var startNavigationController: UINavigationController?

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
        }))
    }

    private func presentStartFlow() {
        let startViewController = StartViewController(store: store)
        startNavigationController = UINavigationController(rootViewController: startViewController)
        if let startFlow = startNavigationController {
            startFlow.setNavigationBarHidden(true, animated: false)
            rootViewController.present(startFlow, animated: false, completion: nil)
        }
    }

    private func dismissStartFlow() {
        startNavigationController?.dismiss(animated: true) { [weak self] in
            self?.startNavigationController = nil
        }
    }

    private func pushPinCreationViewController() {
        let pinCreationViewController = PinCreationViewController(store: store)
        pinCreationViewController.title = "Create New Wallet"
        
        //Access the view as we want to trigger viewDidLoad before it gets pushed.
        //This makes the keyboard slide in from the right.
        let _ = pinCreationViewController.view
        startNavigationController?.setNavigationBarHidden(false, animated: false)
        startNavigationController?.pushViewController(pinCreationViewController, animated: true)
    }

    private func pushStartPaperPhraseCreationViewController() {
        let paperPhraseViewController = StartPaperPhraseViewController(store: store)
        paperPhraseViewController.title = "Paper Key"
        paperPhraseViewController.navigationItem.setHidesBackButton(true, animated: false)
        startNavigationController?.pushViewController(paperPhraseViewController, animated: true)
    }

    private func pushWritePaperPhraseViewController() {
        let writeViewController = WritePaperPhraseViewController(store: store)
        writeViewController.title = "Paper Key"
        startNavigationController?.pushViewController(writeViewController, animated: true)
    }
}
