// 
//  RedeemTransitioningDelegate.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2020-11-26.
//  Copyright © 2020 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import UIKit

class RedeemTransitioningDelegate: NSObject {}

private let redeemDuration = 0.6

extension RedeemTransitioningDelegate: UIViewControllerTransitioningDelegate {
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return PresentRedeemAnimator()
    }

    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return DismissRedeemAnimator()
    }
}

class PresentRedeemAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return redeemDuration
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        let duration = transitionDuration(using: transitionContext)
        let container = transitionContext.containerView
        guard let toVc = transitionContext.viewController(forKey: .to) as? RedeemGiftViewController else { return }
        toVc.blurView.effect = nil
        toVc.container.alpha = 0.0
        toVc.container.transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
        container.addSubview(toVc.view)
        toVc.view.constrain(toSuperviewEdges: nil)
        UIView.spring(duration, animations: {
            toVc.blurView.effect = UIBlurEffect(style: .light)
            toVc.container.alpha = 1.0
            toVc.container.transform = .identity
        }, completion: { _ in
            transitionContext.completeTransition(true)
        })
    }
}

class DismissRedeemAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return redeemDuration
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        let duration = transitionDuration(using: transitionContext)
        guard let fromVc = transitionContext.viewController(forKey: .from) as? RedeemGiftViewController else { return }
        UIView.spring(duration, animations: {
            fromVc.blurView.effect = nil
            fromVc.container.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
            fromVc.container.alpha = 0.0
        }, completion: { _ in
            transitionContext.completeTransition(true)
        })
    }
}
