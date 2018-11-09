//
//  RootNavigationController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-12-05.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

class RootNavigationController: UINavigationController {

    var walletManager: BTCWalletManager? {
        didSet {
            guard let walletManager = walletManager else { return }
            if !walletManager.noWallet && Store.state.isLoginRequired {
                let loginView = LoginViewController(isPresentedForLock: false, walletManager: walletManager)
                loginView.transitioningDelegate = loginTransitionDelegate
                loginView.modalPresentationStyle = .overFullScreen
                loginView.modalPresentationCapturesStatusBarAppearance = true
                present(loginView, animated: false, completion: {
                    self.tempLoginView.remove()
                })
            }
        }
    }

    private var tempLoginView = LoginViewController(isPresentedForLock: false)
    private let loginTransitionDelegate = LoginTransitionDelegate()

    override func viewDidLoad() {
        setDarkStyle()
        self.addChildViewController(tempLoginView, layout: {
            tempLoginView.view.constrain(toSuperviewEdges: nil)
        })
        guardProtected(queue: DispatchQueue.main) {
            if BTCWalletManager.staticNoWallet {
                self.tempLoginView.remove()
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
        self.delegate = self
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
}

extension RootNavigationController: UINavigationControllerDelegate {
    func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
        if viewController is HomeScreenViewController {
            UserDefaults.selectedCurrencyCode = nil
            navigationBar.tintColor = .navigationTint
        } else if let accountView = viewController as? AccountViewController {
            UserDefaults.selectedCurrencyCode = accountView.currency.code
            UserDefaults.mostRecentSelectedCurrencyCode = accountView.currency.code
        }
    }
    
    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        if viewController is AccountViewController {
            navigationBar.tintColor = .white
        }
    }
}
