//
//  UIView+AnimationAdditions.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-11-28.
//  Copyright © 2016-2019 Breadwinner AG. All rights reserved.
//

import UIKit

extension UIView {
    static func spring(_ duration: TimeInterval, delay: TimeInterval, animations: @escaping () -> Void, completion: @escaping (Bool) -> Void) {
        UIViewPropertyAnimator.springAnimation(duration, delay: delay, animations: animations, completion: {_ in completion(true) })
    }

    static func spring(_ duration: TimeInterval, animations: @escaping () -> Void, completion: @escaping (Bool) -> Void) {
        UIViewPropertyAnimator.springAnimation(duration, animations: animations, completion: {_ in completion(true) })
    }
}
