//
//  ModalAnimator.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-11-28.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

private let modalHeight: CGFloat = 368.0

protocol ModalAnimating {
    func visibleFrame(fromFrame: CGRect) -> CGRect
    func hiddenFrame(fromFrame: CGRect) -> CGRect
}

extension ModalAnimating {
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
