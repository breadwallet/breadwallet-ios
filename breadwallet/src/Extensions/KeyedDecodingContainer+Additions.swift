//
//  KeyedDecodingContainer+Additions.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2018-01-11.
//  Copyright © 2018 breadwallet LLC. All rights reserved.
//

import Foundation

public extension KeyedDecodingContainer {
    public func decodeFromString<T: LosslessStringConvertible>(_ type: T.Type, forKey key: Key) throws -> T {
        let stringValue = try self.decode(String.self, forKey: key)
        guard let value = T(stringValue) else {
            let context = DecodingError.Context(codingPath: codingPath, debugDescription: "Could not parse JSON string to a typed object")
            throw DecodingError.dataCorrupted(context)
        }
        return value
    }
}
