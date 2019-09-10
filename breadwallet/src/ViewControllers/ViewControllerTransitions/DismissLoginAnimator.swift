//
//  DismissLoginAnimator.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-02-07.
//  Copyright © 2017-2019 Breadwinner AG. All rights reserved.
//

import UIKit

class DismissLoginAnimator: NSObject, UIViewControllerAnimatedTransitioning {

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.4
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard transitionContext.isAnimated else { return }
        let duration = transitionDuration(using: transitionContext)
        guard let fromView = transitionContext.view(forKey: .from) else { assert(false, "Missing from view"); return }
        UIView.animate(withDuration: duration, animations: {
            fromView.alpha = 0.0
        }, completion: { _ in
            transitionContext.completeTransition(true)
        })
    }
}
