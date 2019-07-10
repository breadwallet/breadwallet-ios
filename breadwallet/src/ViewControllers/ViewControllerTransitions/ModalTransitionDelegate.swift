//
//  ModalTransitionDelegate.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-11-25.
//  Copyright © 2016-2019 Breadwinner AG. All rights reserved.
//

import UIKit

enum ModalType {
    case regular
    case transactionDetail
}

class ModalTransitionDelegate: NSObject, Subscriber {

    // MARK: - Public
    init(type: ModalType) {
        self.type = type
        super.init()
    }

    func reset() {
        isInteractive = false
        presentedViewController = nil
        if let panGr = panGestureRecognizer {
            UIApplication.shared.keyWindow?.removeGestureRecognizer(panGr)
        }
        Store.trigger(name: .showStatusBar)
    }

    var shouldDismissInteractively = true
    // MARK: - Private
    fileprivate let type: ModalType
    fileprivate var isInteractive: Bool = false
    fileprivate let interactiveTransition = UIPercentDrivenInteractiveTransition()
    fileprivate var presentedViewController: UIViewController?
    fileprivate var panGestureRecognizer: UIPanGestureRecognizer?

    private var yVelocity: CGFloat = 0.0
    private var progress: CGFloat = 0.0
    private let velocityThreshold: CGFloat = 50.0
    private let progressThreshold: CGFloat = 0.5

    @objc fileprivate func didUpdate(gr: UIPanGestureRecognizer) {
        guard shouldDismissInteractively else { return }
        switch gr.state {
        case .began:
            isInteractive = true
            presentedViewController?.dismiss(animated: true, completion: nil)
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
        @unknown default:
            assertionFailure("unknown gesture")
        }
    }

    private var transitionShouldFinish: Bool {
        if progress > progressThreshold || yVelocity > velocityThreshold {
            return true
        } else {
            return false
        }
    }
}

extension ModalTransitionDelegate: UIViewControllerTransitioningDelegate {
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        presentedViewController = presented
        return PresentModalAnimator(shouldCoverBottomGap: type == .regular, completion: {
            let panGr = UIPanGestureRecognizer(target: self, action: #selector(ModalTransitionDelegate.didUpdate(gr:)))
            UIApplication.shared.keyWindow?.addGestureRecognizer(panGr)
            self.panGestureRecognizer = panGr
        })
    }

    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return DismissModalAnimator()
    }

    func interactionControllerForDismissal(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        return isInteractive ? interactiveTransition : nil
    }
}
