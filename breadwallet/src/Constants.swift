//
//  Constants.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-24.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

let π: CGFloat = CGFloat(M_PI)

struct Padding {
    subscript(multiplier: Int) -> CGFloat {
        get {
            return CGFloat(multiplier) * 8.0
        }
    }
}

struct C {

    static let padding = Padding()

    struct Sizes {
        static let buttonHeight: CGFloat = 48.0
    }

    static var defaultTintColor: UIColor = {
        return UIView().tintColor
    }()
}
