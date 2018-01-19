//
//  RootNavigationController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-12-05.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

class RootNavigationController : UINavigationController {

    var walletManager: WalletManager? {
        didSet {
            guard let walletManager = walletManager else { return }
            if !walletManager.noWallet {
                let loginView = LoginViewController(isPresentedForLock: false, walletManager: walletManager)
                loginView.transitioningDelegate = loginTransitionDelegate
                loginView.modalPresentationStyle = .overFullScreen
                loginView.modalPresentationCapturesStatusBarAppearance = true
                loginView.shouldSelfDismiss = true
                present(loginView, animated: false, completion: {
                    self.tempLoginView?.remove()
                    //todo - attempt show welcome here
                })
            }
        }
    }

//    var store: Store? {
//        didSet {
//            guard let store = store else { return }
//            self.tempLoginView = LoginViewController(store: store, isPresentedForLock: false)
//        }
//    }
    private var tempLoginView: LoginViewController?
    private let welcomeTransitingDelegate = PinTransitioningDelegate()
    private let loginTransitionDelegate = LoginTransitionDelegate()

    override func viewDidLoad() {
        guardProtected(queue: DispatchQueue.main) {
            if !WalletManager.staticNoWallet {
                if let tempLoginView = self.tempLoginView {
                    self.addChildViewController(tempLoginView, layout: {
                        tempLoginView.view.constrain(toSuperviewEdges: nil)
                    })
                }
            } else {
                let tempStartView = StartViewController(didTapCreate: {}, didTapRecover: {})
                self.addChildViewController(tempStartView, layout: {
                    tempStartView.view.constrain(toSuperviewEdges: nil)
                    tempStartView.view.isUserInteractionEnabled = false
                })
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: {
                    tempStartView.remove()
                })
            }
        }
    }

    private func attemptShowWelcomeView() {
        if !UserDefaults.hasShownWelcome {
            let welcome = WelcomeViewController()
            welcome.transitioningDelegate = welcomeTransitingDelegate
            welcome.modalPresentationStyle = .overFullScreen
            welcome.modalPresentationCapturesStatusBarAppearance = true
            welcomeTransitingDelegate.shouldShowMaskView = false
            //loginView.present(welcome, animated: true, completion: nil)
            UserDefaults.hasShownWelcome = true
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        if topViewController is HomeScreenViewController {
            return .default
        } else {
            return .lightContent
        }
    }
}
