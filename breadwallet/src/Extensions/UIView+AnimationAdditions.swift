//
//  UIView+AnimationAdditions.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-11-28.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

extension UIView {
    static func spring(_ duration: TimeInterval, delay: TimeInterval, animations: @escaping () -> Void, completion: @escaping (Bool) -> Void) {
        if #available(iOS 10.0, *) {
            UIViewPropertyAnimator.springAnimation(duration, delay: delay, animations: animations, completion: {_ in completion(true) })
        } else {
            UIView.animate(withDuration: duration, delay: delay, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.0, options: [], animations: animations, completion: completion)
        }
    }

    static func spring(_ duration: TimeInterval, animations: @escaping () -> Void, completion: @escaping (Bool) -> Void) {
        if #available(iOS 10.0, *) {
            UIViewPropertyAnimator.springAnimation(duration, animations: animations, completion: {_ in completion(true) })
        } else {
            UIView.animate(withDuration: duration, delay: 0.0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.0, options: [], animations: animations, completion: completion)
        }
    }
}
