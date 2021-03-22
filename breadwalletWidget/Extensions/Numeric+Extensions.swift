//
//  Numeric+Extensions.swift
//  ChartDemo
//
//  Created by stringcode on 11/02/2021.
//  Copyright © 2021 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import Foundation
import CoreGraphics

// MARK: - Int type conversion

extension Int {
    
    var float: Float {
        Float(self)
    }
    
    var double: Double {
        Double(self)
    }
    
    var cgfloat: CGFloat {
        CGFloat(self)
    }
}

// MARK: - Float type conversion

extension Float {
    
    var int: Int {
        Int(self)
    }
    
    var double: Double {
        Double(self)
    }
    
    var cgfloat: CGFloat {
        CGFloat(self)
    }
}

// MARK: - Double type conversion

extension Double {
    
    var int: Int {
        Int(self)
    }
    
    var float: Float {
        Float(self)
    }
    
    var cgfloat: CGFloat {
        CGFloat(self)
    }
}
