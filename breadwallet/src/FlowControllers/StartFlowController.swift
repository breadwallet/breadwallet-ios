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
                switch $0.pinCreationStep {
                    case .start:
                        print("start")
                    case .confirm:
                        print("confirm")
                    case .save:
                        print("save")
                    case .none:
                        print("none")
                }
        }))
    }

    private func presentStartFlow() {
        let startViewController = StartViewController(store: store)
        startViewController.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Close", style: .plain, target: self, action: #selector(self.dismiss))
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

    @objc func dismiss() {
        store.perform(action: HideStartFlow())
    }
}
