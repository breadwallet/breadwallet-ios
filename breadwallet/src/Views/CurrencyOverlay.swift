//
//  CurrencyOverlay.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-12-27.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

struct CurrencyOverlay {
    let top = UIView(color: .transparentBlack)
    let middle = UIView(color: .transparentBlack)
    let bottom = UIView(color: .transparentBlack)
    let blocker = UIView()

    var alpha: CGFloat = 0.0 {
        didSet {
            views.forEach {
                $0.alpha = alpha
            }
        }
    }

    mutating func removeFromSuperview() {
        views.forEach {
            $0.removeFromSuperview()
        }
    }

    private lazy var views: [UIView] = {
        return [self.top, self.middle, self.bottom, self.blocker]
    }()
}
