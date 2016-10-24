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
        addStoreSubscription()
    }

    private func addStoreSubscription() {
        let subscription = GranularSubscription(selector: { $0.isStartFlowVisible }, callback: { isStartFlowVisible in
            if isStartFlowVisible {
                self.presentStartFlow()
            } else {
                self.dismissStartFlow()
            }
        })
        store.granularSubscription(self, subscription: subscription)
    }

    private func presentStartFlow() {
        let startViewController = StartViewController()
        startViewController.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Close", style: .plain, target: self, action: #selector(self.dismiss))
        startNavigationController = UINavigationController(rootViewController: startViewController)
        if let startFlow = startNavigationController {
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
