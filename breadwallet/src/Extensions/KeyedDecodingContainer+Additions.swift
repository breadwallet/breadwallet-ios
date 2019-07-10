//
//  KeyedDecodingContainer+Additions.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2018-01-11.
//  Copyright © 2018-2019 Breadwinner AG. All rights reserved.
//

import Foundation

public extension KeyedDecodingContainer {
    func decodeFromString<T: LosslessStringConvertible>(_ type: T.Type, forKey key: Key) throws -> T {
        let stringValue = try self.decode(String.self, forKey: key)
        guard let value = T(stringValue) else {
            let context = DecodingError
                .Context(codingPath: codingPath,
                         debugDescription: "Could not parse JSON string (\(stringValue)) to a typed object (\(key.stringValue): \(String(describing: T.self)))")
            throw DecodingError.dataCorrupted(context)
        }
        return value
    }
    
    func decodeFromHexString<T: FixedWidthInteger>(_ type: T.Type, forKey key: Key) throws -> T {
        let stringValue = try self.decode(String.self, forKey: key)
        guard let value = T(stringValue.withoutHexPrefix, radix: 16) else {
            let context = DecodingError
                .Context(codingPath: codingPath,
                         debugDescription: "Could not parse JSON hex string (\(stringValue)) to integer type (\(key.stringValue): \(String(describing: T.self)))")
            throw DecodingError.dataCorrupted(context)
        }
        return value
    }
}
