//
//  CGTypes+Extensions.swift
//  ChartDemo
//
//  Created by stringcode on 11/02/2021.
//  Copyright © 2021 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import Foundation
import CoreGraphics

extension CGSize {
    
    var maxXmaxY: CGPoint {
        return .init(x: width, y: height)
    }
    
    var minXmaxY: CGPoint {
        return .init(x: 0, y: height)
    }
}
