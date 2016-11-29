//
//  UIViewPropertyAnimator+BRWAdditions.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-26.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

@available(iOS 10.0, *)
extension UIViewPropertyAnimator {

    static func springAnimation(_ animations: @escaping ()->Void) -> UIViewPropertyAnimator {
        let springParameters = UISpringTimingParameters(dampingRatio: 0.7)
        let animator = UIViewPropertyAnimator(duration: 0.6, timingParameters: springParameters)
        animator.addAnimations(animations)
        return animator
    }

    static func springAnimation(_ duration: TimeInterval, animations: @escaping () -> Void, completion: @escaping (UIViewAnimatingPosition) -> Void) {
        let springParameters = UISpringTimingParameters(dampingRatio: 0.7)
        let animator = UIViewPropertyAnimator(duration: duration, timingParameters: springParameters)
        animator.addAnimations(animations)
        animator.addCompletion(completion)
        animator.startAnimation()
    }

}
