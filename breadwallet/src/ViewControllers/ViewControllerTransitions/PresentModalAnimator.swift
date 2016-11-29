//
//  PresentModalAnimator.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-11-28.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

class PresentModalAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    private let modalHeight: CGFloat = 368.0
    private let callback: () -> Void

    init(callback: @escaping () -> Void) {
        self.callback = callback
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
            self.callback()
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
