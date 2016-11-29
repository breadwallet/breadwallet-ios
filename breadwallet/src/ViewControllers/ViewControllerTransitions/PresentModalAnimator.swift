//
//  PresentModalAnimator.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-11-28.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

class PresentModalAnimator: NSObject, UIViewControllerAnimatedTransitioning, ModalAnimating {
    
    private let completion: () -> Void

    init(completion: @escaping () -> Void) {
        self.completion = completion
    }

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.4
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard transitionContext.isAnimated else { return }
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
            self.completion()
        })
    }
}
