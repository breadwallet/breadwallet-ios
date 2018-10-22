//
//  String+Additions.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-12-12.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit
import BRCore

extension String {
    var isValidAddress: Bool {
        guard lengthOfBytes(using: .utf8) > 0 else { return false }
        return BRAddressIsValid(self) != 0
    }

    var isValidBCHAddress: Bool {
        return bitcoinAddr.isValidAddress
    }

    var isValidEmailAddress: Bool {
        guard count > 0 else { return false }
        
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,10}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        
        return emailPredicate.evaluate(with: self)
    }
    
    var bCashAddr: String {
        var addr = [CChar](repeating: 0, count: 55)
        BRBCashAddrEncode(&addr, self)
        return String(cString: addr)
    }
    
    var bitcoinAddr: String {
        var addr = [CChar](repeating: 0, count: 36)
        BRBCashAddrDecode(&addr, self)
        return String(cString: addr)
    }
    
    var isValidEthAddress: Bool {
        let pattern = "^0[xX][0-9a-fA-F]{40}$"
        return range(of: pattern, options: .regularExpression) != nil
    }

    var sanitized: String {
        return applyingTransform(.toUnicodeName, reverse: false) ?? ""
    }

    func ltrim(_ chars: Set<Character>) -> String {
        if let index = self.index(where: {!chars.contains($0)}) {
            return String(self[index..<self.endIndex])
        } else {
            return ""
        }
    }
    
    func rtrim(_ chars: Set<Character>) -> String {
        if let index = self.reversed().index(where: {!chars.contains($0)}) {
            return String(self[self.startIndex...self.index(before: index.base)])
        } else {
            return ""
        }
    }

    func nsRange(from range: Range<Index>) -> NSRange {
        let location = utf16.distance(from: utf16.startIndex, to: range.lowerBound)
        let length = utf16.distance(from: range.lowerBound, to: range.upperBound)
        return NSRange(location: location, length: length)
    }
}

private let startTag = "<b>"
private let endTag = "</b>"

//Convert string with <b> tags to attributed string
extension String {
    var tagsRemoved: String {
        return replacingOccurrences(of: startTag, with: "").replacingOccurrences(of: endTag, with: "")
    }

    var attributedStringForTags: NSAttributedString {
        let output = NSMutableAttributedString()
        let scanner = Scanner(string: self)
        let endCount = tagsRemoved.utf8.count
        var i = 0
        while output.string.utf8.count < endCount || i < 50 {
            var regular: NSString?
            var bold: NSString?
            scanner.scanUpTo(startTag, into: &regular)
            scanner.scanUpTo(endTag, into: &bold)
            if let regular = regular {
                output.append(NSAttributedString(string: (regular as String).tagsRemoved, attributes: UIFont.regularAttributes))
            }
            if let bold = bold {
                output.append(NSAttributedString(string: (bold as String).tagsRemoved, attributes: UIFont.boldAttributes))
            }
            i += 1
        }
        return output
    }
}

// MARK: - Hex String conversions
extension String {
    var hexToData: Data? {
        let scalars = withoutHexPrefix.unicodeScalars
        var bytes = Array<UInt8>(repeating: 0, count: (scalars.count + 1) >> 1)
        for (index, scalar) in scalars.enumerated() {
            guard var nibble = scalar.nibble else { return nil }
            if index & 1 == 0 {
                nibble <<= 4
            }
            bytes[index >> 1] |= nibble
        }
        return Data(bytes: bytes)
    }
    
    var withoutHexPrefix: String {
        guard self.hasPrefix("0x") else { return self }
        return String(self.dropFirst(2))
    }
    
    var withHexPrefix: String {
        guard !self.hasPrefix("0x") else { return self }
        return "0x\(self)"
    }
    
    var trimmedLeadingZeros: String {
        let trimmed = self.ltrim(["0"])
        return trimmed.count > 0 ? trimmed : "0"
    }
    
    func leftPadding(toLength: Int, withPad character: Character) -> String {
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
}

extension UnicodeScalar {
    var nibble: UInt8? {
        if 48 <= value && value <= 57 {
            return UInt8(value - 48)
        }
        else if 65 <= value && value <= 70 {
            return UInt8(value - 55)
        }
        else if 97 <= value && value <= 102 {
            return UInt8(value - 87)
        }
        return nil
    }
}

// UInt256 support
extension String {
    init(_ value: UInt256, radix: Int = 10) {
        self = value.string(radix: radix)
    }
    
    func usDecimalString(fromLocale inputLocale: Locale) -> String {
        let expectedFormat = NumberFormatter()
        expectedFormat.numberStyle = .decimal
        expectedFormat.locale = Locale(identifier: "en_US")
        
        // createUInt256ParseDecimal expects en_us formatted string
        let inputFormat = NumberFormatter()
        inputFormat.locale = inputLocale
        
        // remove grouping separators
        var sanitized = self.replacingOccurrences(of: inputFormat.currencyGroupingSeparator, with: "")
        sanitized = sanitized.replacingOccurrences(of: inputFormat.groupingSeparator, with: "")
        
        // replace decimal separators
        sanitized = sanitized.replacingOccurrences(of: inputFormat.currencyDecimalSeparator, with: expectedFormat.decimalSeparator)
        sanitized = sanitized.replacingOccurrences(of: inputFormat.decimalSeparator, with: expectedFormat.decimalSeparator)
        
        // createUInt256ParseDecimal does not accept integers
        if !sanitized.contains(expectedFormat.decimalSeparator) {
            sanitized += expectedFormat.decimalSeparator
        }
        
        return sanitized
    }
}
