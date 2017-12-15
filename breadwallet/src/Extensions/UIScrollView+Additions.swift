//
//  UIScrollView+Additions.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-12-14.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit

extension UIScrollView {
    func verticallyOffsetContent(_ deltaY: CGFloat) {
        contentOffset = CGPoint(x: contentOffset.x, y: contentOffset.y - deltaY)
        contentInset = UIEdgeInsetsMake(contentInset.top + deltaY, contentInset.left, contentInset.bottom, contentInset.right)
        scrollIndicatorInsets = contentInset
    }
}
