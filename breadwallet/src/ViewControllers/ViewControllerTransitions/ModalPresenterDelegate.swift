//
//  ModalPresenterDelegate.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-11-25.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

class ModalPresenterDelegate: NSObject {

    var isInteractive: Bool = false
    let percentDrivenInteractiveTransition = UIPercentDrivenInteractiveTransition()

    var presentedViewController: UIViewController?
    var didDismiss: (() -> Void)?

    @objc func didUpdate(gr: UIPanGestureRecognizer) {
        switch gr.state {
            case .began:
                isInteractive = true
                presentedViewController?.dismiss(animated: true, completion: {})
            case .changed:
                let yOffset = gr.translation(in: presentedViewController!.view).y
                let progress = yOffset/presentedViewController!.view.bounds.height
                percentDrivenInteractiveTransition.update(progress)
            case .cancelled:
                percentDrivenInteractiveTransition.cancel()
            case .ended:
                percentDrivenInteractiveTransition.finish()
                isInteractive = false
                didDismiss?()
            case .failed:
                percentDrivenInteractiveTransition.cancel()
            case .possible:
                break
        }
    }
}

extension ModalPresenterDelegate: UIViewControllerTransitioningDelegate {
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        presentedViewController = presenting
        return PresentModalAnimator(callback: {
            let gr = UIPanGestureRecognizer(target: self, action: #selector(ModalPresenterDelegate.didUpdate(gr:)))
            UIApplication.shared.keyWindow?.addGestureRecognizer(gr)
        })
    }

    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return DismissModalAnimator()
    }

    func interactionControllerForDismissal(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        return isInteractive ? percentDrivenInteractiveTransition : nil
    }
}
