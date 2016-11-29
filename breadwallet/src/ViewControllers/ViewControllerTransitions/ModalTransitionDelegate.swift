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
    fileprivate var gestureRecognizer: UIPanGestureRecognizer?
    private var yVelocity: CGFloat = 0.0
    private var progress: CGFloat = 0.0
    private let velocityThreshold: CGFloat = 50.0
    private let progressThreshold: CGFloat = 0.5

    @objc func didUpdate(gr: UIPanGestureRecognizer) {
        switch gr.state {
            case .began:
                isInteractive = true
                presentedViewController?.dismiss(animated: true, completion: {})
            case .changed:
                guard let vc = presentedViewController else { break }
                let yOffset = gr.translation(in: vc.view).y
                let progress = yOffset/vc.view.bounds.height
                yVelocity = gr.velocity(in: vc.view).y
                self.progress = progress
                interactiveTransition.update(progress)
            case .cancelled:
                reset()
                interactiveTransition.cancel()
            case .ended:
                if transitionShouldFinish {
                    reset()
                    interactiveTransition.finish()
                } else {
                    isInteractive = false
                    interactiveTransition.cancel()
                }
            case .failed:
                break
            case .possible:
                break
        }
    }

    private var transitionShouldFinish: Bool {
        if progress > progressThreshold || yVelocity > velocityThreshold {
            return true
        } else {
            return false
        }
    }

    private func reset() {
        isInteractive = false
        if let gr = gestureRecognizer {
            UIApplication.shared.keyWindow?.removeGestureRecognizer(gr)
        }
    }
}

extension ModalTransitionDelegate: UIViewControllerTransitioningDelegate {
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        presentedViewController = presenting
        return PresentModalAnimator(completion: {
            let gr = UIPanGestureRecognizer(target: self, action: #selector(ModalTransitionDelegate.didUpdate(gr:)))
            UIApplication.shared.keyWindow?.addGestureRecognizer(gr)
            self.gestureRecognizer = gr
        })
    }

    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return DismissModalAnimator()
    }

    func interactionControllerForDismissal(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        return isInteractive ? interactiveTransition : nil
    }
}
