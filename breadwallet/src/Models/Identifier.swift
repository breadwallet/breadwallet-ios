// 
//  Identifier.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2019-09-12.
//  Copyright © 2019 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import Foundation

/// Type-safe string-based identifier
struct Identifier<Value>: Hashable {
    let rawValue: String
}

extension Identifier: ExpressibleByStringLiteral {
    init(stringLiteral value: String) {
        rawValue = value
    }
}

extension Identifier: CustomStringConvertible {
    var description: String {
        return rawValue
    }
}

extension Identifier: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        rawValue = try container.decode(String.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
