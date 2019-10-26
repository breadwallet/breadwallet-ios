//
//  LoginTransitionDelegate.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-02-07.
//  Copyright © 2017-2019 Breadwinner AG. All rights reserved.
//

import UIKit

class LoginTransitionDelegate: NSObject, UIViewControllerTransitioningDelegate {
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return DismissLoginAnimator()
    }
}
