//
//  ModalTransitionDelegate.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-11-25.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

class ModalTransitionDelegate : NSObject, Subscriber {

    fileprivate var isInteractive: Bool = false
    fileprivate let interactiveTransition = UIPercentDrivenInteractiveTransition()
    fileprivate var presentedViewController: UIViewController?
    fileprivate var panGestureRecognizer: UIPanGestureRecognizer? {
        didSet {
            panGestureRecognizer?.delegate = self
        }
    }
    fileprivate var tapGestureRecognizer: UITapGestureRecognizer? {
        didSet {
            tapGestureRecognizer?.delegate = self
        }
    }

    private var yVelocity: CGFloat = 0.0
    private var progress: CGFloat = 0.0
    private let velocityThreshold: CGFloat = 50.0
    private let progressThreshold: CGFloat = 0.5
    fileprivate var isModalDismissalBlocked = false
    private let store: Store

    init(store: Store) {
        self.store = store
        super.init()
        addSubscriptions()
    }

    func reset() {
        isInteractive = false
        if let panGr = panGestureRecognizer {
            UIApplication.shared.keyWindow?.removeGestureRecognizer(panGr)
        }

        if let tapGr = tapGestureRecognizer {
            UIApplication.shared.keyWindow?.removeGestureRecognizer(tapGr)
        }
    }

    private func addSubscriptions() {
        store.subscribe(self, selector: { $0.isModalDismissalBlocked != $1.isModalDismissalBlocked
        }, callback: {
            self.isModalDismissalBlocked = $0.isModalDismissalBlocked
        })
    }

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

    @objc func didTap(gr: UITapGestureRecognizer) {
        reset()
        presentedViewController?.dismiss(animated: true, completion: {})
    }

    private var transitionShouldFinish: Bool {
        if progress > progressThreshold || yVelocity > velocityThreshold {
            return true
        } else {
            return false
        }
    }
}

extension ModalTransitionDelegate : UIViewControllerTransitioningDelegate {
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        presentedViewController = presented
        return PresentModalAnimator(completion: {
            let panGr = UIPanGestureRecognizer(target: self, action: #selector(ModalTransitionDelegate.didUpdate(gr:)))
            UIApplication.shared.keyWindow?.addGestureRecognizer(panGr)
            self.panGestureRecognizer = panGr

            let tapGR = UITapGestureRecognizer(target: self, action: #selector(ModalTransitionDelegate.didTap(gr:)))
            UIApplication.shared.keyWindow?.addGestureRecognizer(tapGR)
            self.tapGestureRecognizer = tapGR
        })
    }

    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return DismissModalAnimator()
    }

    func interactionControllerForDismissal(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        return isInteractive ? interactiveTransition : nil
    }
}

extension ModalTransitionDelegate : UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard !isModalDismissalBlocked else { return false }
        if gestureRecognizer == tapGestureRecognizer {
            let location = gestureRecognizer.location(in: presentedViewController?.view)
            if location.y < 0 {
                return true
            } else {
                return false
            }
        } else {
            return true
        }
    }
}
