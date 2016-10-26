//
//  AlertCoordinator.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-25.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

class AlertCoordinator: Subscriber {

    private let store: Store
    private let window: UIWindow
    private let simpleAlertView: UIView = {
        let view = UIView()
        view.backgroundColor = .brand
        view.layer.cornerRadius = 6.0
        return view
    }()
    private let alertHeight: CGFloat = 260.0

    init(store: Store, window: UIWindow) {
        self.store = store
        self.window = window

        addSubscriptions()
    }

    func addSubscriptions() {
        store.subscribe(self, subscription: Subscription(
            selector: { _,_ in true },
            callback: { state in
                if case .save(_) = state.pinCreationStep {
                    self.presentAlert()
                }
        }))
    }

    func presentAlert() {

        //TODO - This is a total hack to grab the window that keyboard is in
        //After pin creation, the alert view needs to be presented over the keyboard
        let windowsCount = UIApplication.shared.windows.count
        let keyboardWindow = UIApplication.shared.windows[windowsCount - 1]
        let size = keyboardWindow.bounds.size

        keyboardWindow.addSubview(simpleAlertView)

        let topConstraint = simpleAlertView.constraint(.top, toView: keyboardWindow, constant: size.height)
        simpleAlertView.constrain([
                simpleAlertView.constraint(.width, constant: size.width),
                simpleAlertView.constraint(.height, constant: alertHeight + 25.0),
                simpleAlertView.constraint(.leading, toView: keyboardWindow, constant: nil),
                topConstraint
            ])
        keyboardWindow.layoutIfNeeded()
        if #available(iOS 10.0, *) {
            let springParameters = UISpringTimingParameters(dampingRatio: 0.7)
            let animator = UIViewPropertyAnimator(duration: 0.6, timingParameters: springParameters)
            animator.addAnimations {
                topConstraint.constant = size.height - self.alertHeight
                keyboardWindow.layoutIfNeeded()
            }
            animator.startAnimation()
        }
    }

}
