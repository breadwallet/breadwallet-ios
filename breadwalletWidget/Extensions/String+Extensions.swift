//
//  String+Extensions.swift
//  ChartDemo
//
//  Created by stringcode on 11/02/2021.
//  Copyright © 2021 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import Foundation

// MARK: - Extracting number from string

extension String {

    func int() throws  -> Int {
        guard let num = Int(self) else {
            throw ParseError.failedToParseType(typeStr: "Int", fromStr: self)
        }
        return num
    }

    func double() throws  -> Double {
        guard let num = Double(self) else {
            throw ParseError.failedToParseType(typeStr: "Double", fromStr: self)
        }
        return num
    }
    
    func float() throws  -> Float {
        guard let num = Float(self) else {
            throw ParseError.failedToParseType(typeStr: "Float", fromStr: self)
        }
        return num
    }

    enum ParseError: Error {

        case failedToParseType(typeStr: String, fromStr: String)

        var errorDescription: String? {
            switch self {
            case let .failedToParseType(typeStr, fromStr):
                return "Failed to parse \(typeStr) out of \(fromStr)"
            }
        }
    }
}
