//
//  StartFlowController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-22.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

class StartFlowController: Subscriber {

    let store: Store
    let rootViewController: UIViewController
    var startNavigationController: UINavigationController?

    init(store: Store, rootViewController: UIViewController) {
        self.store = store
        self.rootViewController = rootViewController
        addStoreSubscription()
    }

    private func addStoreSubscription() {
        //TODO - If subscrib had the ability to have granular notifications,
        //this check for a nil startNavigationController wouldn't be necessary
        store.subscribe(self) { state in
            if state.isStartFlowVisible && self.startNavigationController == nil {
                self.presentStartFlow()
            } else if !state.isStartFlowVisible && self.startNavigationController != nil {
                self.dismissStartFlow()
            }
        }
    }

    private func presentStartFlow() {
        let startViewController = StartViewController()
        startViewController.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Close", style: .plain, target: self, action: #selector(self.dismiss))
        self.startNavigationController = UINavigationController(rootViewController: startViewController)
        self.rootViewController.present(self.startNavigationController!, animated: false, completion: {})
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
