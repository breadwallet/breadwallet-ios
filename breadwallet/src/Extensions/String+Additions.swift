//
//  String+Additions.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-12-12.
//  Copyright © 2016-2019 Breadwinner AG. All rights reserved.
//

import UIKit
import BRCrypto

extension String {
    func matches(regularExpression pattern: String) -> Bool {
        return range(of: pattern, options: .regularExpression) != nil
    }

    var isValidEmailAddress: Bool {
        guard !isEmpty else { return false }
        
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,10}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        
        return emailPredicate.evaluate(with: self)
    }

    var sanitized: String {
        return applyingTransform(.toUnicodeName, reverse: false) ?? ""
    }

    func ltrim(_ chars: Set<Character>) -> String {
        if let index = self.firstIndex(where: {!chars.contains($0)}) {
            return String(self[index..<self.endIndex])
        } else {
            return ""
        }
    }
    
    func rtrim(_ chars: Set<Character>) -> String {
        if let index = self.reversed().firstIndex(where: {!chars.contains($0)}) {
            return String(self[self.startIndex...self.index(before: index.base)])
        } else {
            return ""
        }
    }
    
    func trim(_ string: String) -> String {
        return replacingOccurrences(of: string, with: "")
    }
    
    func toMaxLength(_ length: Int) -> String {
        guard count > length else { return self }
        let lastIndex = index(startIndex, offsetBy: length)
        return String(self[..<lastIndex])
    }

    func nsRange(from range: Range<Index>) -> NSRange {
        let location = utf16.distance(from: utf16.startIndex, to: range.lowerBound)
        let length = utf16.distance(from: range.lowerBound, to: range.upperBound)
        return NSRange(location: location, length: length)
    }

    func truncateMiddle(to length: Int = 10) -> String {
        guard count > length else { return self }

        let headLength = length / 2
        let trailLength = (length - headLength) - 1

        return "\(self.prefix(headLength))…\(self.suffix(trailLength))"
    }
}

// MARK: URL/Query

extension String {
    
    static var urlQuoteCharacterSet: CharacterSet {
        if let cset = (NSMutableCharacterSet.urlQueryAllowed as NSCharacterSet).mutableCopy() as? NSMutableCharacterSet {
            cset.removeCharacters(in: "?=&")
            return cset as CharacterSet
        }
        return NSMutableCharacterSet.urlQueryAllowed as CharacterSet
    }
    
    var urlEscapedString: String {
        return addingPercentEncoding(withAllowedCharacters: String.urlQuoteCharacterSet) ?? ""
    }
    
    // TODO: use URLComponents
    func parseQueryString() -> [String: [String]] {
        var ret = [String: [String]]()
        var strippedString = self
        if String(self[..<self.index(self.startIndex, offsetBy: 1)]) == "?" {
            strippedString = String(self[self.index(self.startIndex, offsetBy: 1)...])
        }
        strippedString = strippedString.replacingOccurrences(of: "+", with: " ")
        strippedString = strippedString.removingPercentEncoding!
        for s in strippedString.components(separatedBy: "&") {
            let kp = s.components(separatedBy: "=")
            if kp.count == 2 {
                if var k = ret[kp[0]] {
                    k.append(kp[1])
                } else {
                    ret[kp[0]] = [kp[1]]
                }
            }
        }
        return ret
    }
}

// MARK: - Hex Conversion

extension String {
    var isValidHexString: Bool {
        return withoutHexPrefix.matches(regularExpression: "^([a-fA-F0-9][a-fA-F0-9])*$")
    }
    
    var hexToData: Data? {
        return CoreCoder.hex.decode(string: self.withoutHexPrefix)
    }
    
    var withoutHexPrefix: String {
        return self.removing(prefix: "0x")
    }
    
    var withHexPrefix: String {
        guard !self.hasPrefix("0x") else { return self }
        return "0x\(self)"
    }
    
    var trimmedLeadingZeros: String {
        let trimmed = self.ltrim(["0"])
        return trimmed.isEmpty ? "0" : trimmed
    }
    
    public func leftPadding(toLength: Int, withPad character: Character) -> String {
        if count < toLength {
            return String(repeatElement(character, count: toLength - count)) + self
        } else {
            return String(self[index(self.startIndex, offsetBy: count - toLength)...])
        }
    }
    
    func leftTrim(toLength: Int) -> String {
        let offset = max(0, count - toLength)
        return String(self[index(self.startIndex, offsetBy: offset)...])
    }
    
    /// Hex string padded to 32-bytes
    var paddedHexString: String {
        return self.withoutHexPrefix.leftPadding(toLength: 64, withPad: "0").withHexPrefix
    }
    
    /// Hex string with 0-padding removed down to 20-bytes
    var unpaddedHexString: String {
        return self.withoutHexPrefix.leftTrim(toLength: 40).withHexPrefix
    }
    
    func removing(prefix: String) -> String {
        guard self.hasPrefix(prefix) else { return self }
        return String(self.dropFirst(prefix.count))
    }
}

// MARK: -

extension Optional where Wrapped == String {
    var isNilOrEmpty: Bool {
        return self?.isEmpty ?? true
    }
}
