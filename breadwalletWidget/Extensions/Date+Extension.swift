//
//  Date+Extension.swift
//  ChartDemo
//
//  Created by stringcode on 11/02/2021.
//  Copyright © 2021 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import Foundation

extension Date {
    
    func adding(minutes: Double) -> Date {
        return addingTimeInterval(60 * minutes)
    }
}
