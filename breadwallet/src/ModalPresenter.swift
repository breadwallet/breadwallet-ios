//
//  AlertCoordinator.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-25.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

class ModalPresenter: Subscriber {

    private let store: Store
    private let window: UIWindow
    private let alertHeight: CGFloat = 260.0
    private let modalPresenterDelegate = ModalPresenterDelegate()

    init(store: Store, window: UIWindow) {
        self.store = store
        self.window = window
        addSubscriptions()
        addModalSubscriptions()
    }

    private func addSubscriptions() {
        store.subscribe(self,
            selector: { _,_ in true },
            callback: { state in
                if case .save(_) = state.pinCreationStep {
                    self.presentAlert(.pinSet) {
                        self.store.perform(action: PaperPhrase.Start())
                    }
                }

                if case .confirmed(_) = state.paperPhraseStep {
                    self.presentAlert(.paperKeySet) {
                        self.store.perform(action: HideStartFlow())
                    }
                }
        })
    }

    private func addModalSubscriptions() {
        store.subscribe(self,
                        selector: { $0.rootModal != $1.rootModal},
                        callback: { self.presentModal($0.rootModal) })
    }

    private func presentModal(_ type: RootModal) {
        if type == .menu {
            let menu = MenuViewController()
            menu.didDismiss = {
                self.store.perform(action: RootModalActions.Dismiss())
            }
            menu.transitioningDelegate = modalPresenterDelegate
            window.rootViewController?.present(menu, animated: true, completion: {})
        }
    }

    private func presentAlert(_ type: AlertType, completion: @escaping ()->Void) {

        let alertView = AlertView(type: type)
        let size = activeWindow.bounds.size
        activeWindow.addSubview(alertView)

        let topConstraint = alertView.constraint(.top, toView: activeWindow, constant: size.height)
        alertView.constrain([
                alertView.constraint(.width, constant: size.width),
                alertView.constraint(.height, constant: alertHeight + 25.0),
                alertView.constraint(.leading, toView: activeWindow, constant: nil),
                topConstraint
            ])
        activeWindow.layoutIfNeeded()
        if #available(iOS 10.0, *) {

            let presentAnimator = UIViewPropertyAnimator.springAnimation {
                topConstraint?.constant = size.height - self.alertHeight
                self.activeWindow.layoutIfNeeded()
            }

            let dismissAnimator = UIViewPropertyAnimator.springAnimation {
                topConstraint?.constant = size.height
                self.activeWindow.layoutIfNeeded()
            }

            presentAnimator.addCompletion { _ in
                alertView.animate()
                dismissAnimator.startAnimation(afterDelay: 2.0)
            }

            dismissAnimator.addCompletion { _ in
                completion()
                alertView.removeFromSuperview()
            }

            presentAnimator.startAnimation()
        }
    }

    //TODO - This is a total hack to grab the window that keyboard is in
    //After pin creation, the alert view needs to be presented over the keyboard
    private var activeWindow: UIWindow {
        let windowsCount = UIApplication.shared.windows.count
        if let keyboardWindow = UIApplication.shared.windows.last, windowsCount > 1 {
            return keyboardWindow
        }
        return window
    }
}

class ModalPresenterDelegate: NSObject, UIViewControllerTransitioningDelegate {

    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return ModalTransitionAnimator()
    }

    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return ModalTransitionAnimator()
    }
}

let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))

class ModalTransitionAnimator: NSObject, UIViewControllerAnimatedTransitioning {

    private let modalHeight: CGFloat = 368.0

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.4
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard let toViewController = transitionContext.viewController(forKey: .to) else { assert(false, "Empty to VC"); return }
        if toViewController.isBeingPresented {
            animatePresentation(transitionContext: transitionContext)
        } else {
            animateDismissal(transitionContext: transitionContext)
        }
    }

    func animatePresentation(transitionContext: UIViewControllerContextTransitioning) {
        let duration = transitionDuration(using: transitionContext)
        guard let fromView = transitionContext.view(forKey: .from) else { assert(false, "Empty from view"); return }
        guard let toView = transitionContext.view(forKey: .to) else { assert(false, "Empty to view"); return }
        let container = transitionContext.containerView

        blurView.frame = fromView.frame
        blurView.alpha = 0.0
        container.addSubview(blurView)

        toView.frame = hiddenFrame(fromFrame: fromView.frame)
        container.addSubview(toView)


        UIView.animate(withDuration: duration, animations: {
            blurView.alpha = 0.9
            toView.frame = self.visibleFrame(fromFrame: fromView.frame)
        }, completion: {
            transitionContext.completeTransition($0)
            container.insertSubview(fromView, at: 0)
        })
    }

    func animateDismissal(transitionContext: UIViewControllerContextTransitioning) {
        let duration = transitionDuration(using: transitionContext)
        guard let fromView = transitionContext.view(forKey: .from) else { assert(false, "Empty from view"); return }
        guard let toView = transitionContext.view(forKey: .to) else { assert(false, "Empty to view"); return }

        UIView.animate(withDuration: duration, animations: {
            blurView.alpha = 0.0
            fromView.frame = self.hiddenFrame(fromFrame: toView.frame)
        }, completion: {
            transitionContext.completeTransition($0)
        })
    }

    func visibleFrame(fromFrame: CGRect) -> CGRect {
        var newFrame = fromFrame
        newFrame.origin.y = fromFrame.maxY - modalHeight
        newFrame.size.height = modalHeight
        return newFrame
    }

    func hiddenFrame(fromFrame: CGRect) -> CGRect {
        var newFrame = fromFrame
        newFrame.origin.y = fromFrame.size.height
        newFrame.size.height = modalHeight
        return newFrame
    }
}
