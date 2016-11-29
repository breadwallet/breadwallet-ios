//
//  ModalTransitionDelegate.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-11-25.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

class ModalTransitionDelegate: NSObject {

    fileprivate var isInteractive: Bool = false
    fileprivate let interactiveTransition = UIPercentDrivenInteractiveTransition()
    fileprivate var presentedViewController: UIViewController?
    fileprivate let gestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(ModalTransitionDelegate.didUpdate(gr:)))
    fileprivate let window = UIApplication.shared.keyWindow

    @objc func didUpdate(gr: UIPanGestureRecognizer) {
        switch gr.state {
            case .began:
                isInteractive = true
                presentedViewController?.dismiss(animated: true, completion: {})
            case .changed:
                let yOffset = gr.translation(in: presentedViewController!.view).y
                let progress = yOffset/presentedViewController!.view.bounds.height
                interactiveTransition.update(progress)
            case .cancelled:
                reset()
                interactiveTransition.cancel()
            case .ended:
                reset()
                interactiveTransition.finish()
            case .failed:
                break
            case .possible:
                break
        }
    }

    private func reset() {
        isInteractive = false
        window?.removeGestureRecognizer(gestureRecognizer)
    }
}

extension ModalTransitionDelegate: UIViewControllerTransitioningDelegate {
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        presentedViewController = presenting
        return PresentModalAnimator(callback: {
            self.window?.addGestureRecognizer(self.gestureRecognizer)
        })
    }

    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return DismissModalAnimator()
    }

    func interactionControllerForDismissal(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        return isInteractive ? interactiveTransition : nil
    }
}
