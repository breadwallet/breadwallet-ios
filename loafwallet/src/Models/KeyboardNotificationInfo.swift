//
//  KeyboardNotificationInfo.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-12-28.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

struct KeyboardNotificationInfo {

    var deltaY: CGFloat {
        return endFrame.minY - startFrame.minY
    }
    var animationOptions: UIViewAnimationOptions {
        return UIViewAnimationOptions(rawValue: animationCurve << 16)
    }
    let animationDuration: Double

    init?(_ userInfo: [AnyHashable : Any]?) {
        guard let userInfo = userInfo else { return nil }
        guard let endFrame = userInfo[UIKeyboardFrameEndUserInfoKey] as? NSValue,
            let startFrame = userInfo[UIKeyboardFrameBeginUserInfoKey] as? NSValue,
            let animationDuration = userInfo[UIKeyboardAnimationDurationUserInfoKey] as? NSNumber,
            let animationCurve = userInfo[UIKeyboardAnimationCurveUserInfoKey] as? NSNumber else {
            return nil
        }

        self.endFrame = endFrame.cgRectValue
        self.startFrame = startFrame.cgRectValue
        self.animationDuration = animationDuration.doubleValue
        self.animationCurve = animationCurve.uintValue
    }

    private let endFrame: CGRect
    private let startFrame: CGRect
    private let animationCurve: UInt
}
