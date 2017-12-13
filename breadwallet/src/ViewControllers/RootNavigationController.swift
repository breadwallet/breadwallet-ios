//
//  RootNavigationController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-12-05.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

class RootNavigationController : UINavigationController {

    init(store: Store, rootViewController: UIViewController) {
        self.store = store
        self.tempLoginView = LoginViewController(store: store, isPresentedForLock: false)
        super.init(rootViewController: rootViewController)
    }

    public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        self.store = Store()
        self.tempLoginView = LoginViewController(store: Store(), isPresentedForLock: false)
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var walletManager: WalletManager? {
        didSet {
            guard let walletManager = walletManager else { return }
            if !walletManager.noWallet {
                let loginView = LoginViewController(store: store, isPresentedForLock: false, walletManager: walletManager)
                loginView.transitioningDelegate = loginTransitionDelegate
                loginView.modalPresentationStyle = .overFullScreen
                loginView.modalPresentationCapturesStatusBarAppearance = true
                loginView.shouldSelfDismiss = true
                present(loginView, animated: false, completion: {
                    self.tempLoginView.remove()
                    //todo - attempt show welcome here
                })
            }
        }
    }

    private let tempLoginView: LoginViewController
    private let store: Store
    private let welcomeTransitingDelegate = PinTransitioningDelegate()
    private let loginTransitionDelegate = LoginTransitionDelegate()

    override func viewDidLoad() {
        guardProtected(queue: DispatchQueue.main) {
            if !WalletManager.staticNoWallet {
                self.addChildViewController(self.tempLoginView, layout: {
                    self.tempLoginView.view.constrain(toSuperviewEdges: nil)
                })
            } else {
                let tempStartView = StartViewController(store: self.store, didTapCreate: {}, didTapRecover: {})
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
