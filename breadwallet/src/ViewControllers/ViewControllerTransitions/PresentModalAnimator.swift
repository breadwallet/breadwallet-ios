//
//  PresentModalAnimator.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-11-28.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

class PresentModalAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    
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
        guard let toView = transitionContext.view(forKey: .to) else { assert(false, "Missing to view"); return }
        let container = transitionContext.containerView

        blurView.frame = container.frame
        blurView.alpha = 0.0
        container.addSubview(blurView)

        //This mask view is placed below the bottom of the modal being presented.
        //It needs to be there to cover up the gap left below the modal during the 
        //spring animation. It looks weird if it isn't there.
        let fromFrame = container.frame
        let maskView = UIView(frame: CGRect(x: 0, y: fromFrame.height, width: fromFrame.width, height: 40.0))
        maskView.backgroundColor = .white
        container.addSubview(maskView)

        let finalToViewFrame = toView.frame
        toView.frame = toView.frame.offsetBy(dx: 0, dy: toView.frame.height)
        container.addSubview(toView)

        UIView.spring(duration, animations: {
            maskView.frame = CGRect(x: 0, y: fromFrame.height - 30.0, width: fromFrame.width, height: 40.0)
            blurView.alpha = 0.9
            toView.frame = finalToViewFrame
        }, completion: { _ in
            transitionContext.completeTransition(true)
            //container.insertSubview(fromView, at: 0)
            maskView.removeFromSuperview()
            self.completion()
        })
    }
}
