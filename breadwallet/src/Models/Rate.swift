//
//  Rate.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-01-25.
//  Copyright © 2017-2019 Breadwinner AG. All rights reserved.
//

import Foundation
import UIKit

struct Rate: Equatable {
    let code: String
    let name: String
    let rate: Double
    let reciprocalCode: String
    var currencySymbol: String {
        if let symbol = Rate.symbolMap[code] {
            return symbol
        } else {
            let components: [String: String] = [NSLocale.Key.currencyCode.rawValue: code]
            let identifier = Locale.identifier(fromComponents: components)
            return Locale(identifier: identifier).currencySymbol ?? code
        }
    }

    var maxFractionalDigits: Int {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = self.locale
        return formatter.maximumFractionDigits
    }
    
    static var symbolMap: [String: String] = {
        var map = [String: String]()
        Locale.availableIdentifiers.forEach { identifier in
            let locale = Locale(identifier: identifier)
            guard let code = locale.currencyCode else { return }
            guard let symbol = locale.currencySymbol else { return }

            if let collision = map[code] {
                if collision.utf8.count > symbol.utf8.count {
                    map[code] = symbol
                }
            } else {
                map[code] = symbol
            }
        }
        return map
    }()

    var locale: Locale {
        let components: [String: String] = [NSLocale.Key.currencyCode.rawValue: code]
        let identifier = Locale.identifier(fromComponents: components)
        return Locale(identifier: identifier)
    }
    
    func localString(forCurrency currency: Currency) -> String {
        let placeholderAmount = Amount.zero(currency, rate: self)
        guard let rateText = placeholderAmount.localFormat.string(from: NSNumber(value: rate)) else { return "" }
        return rateText
    }

    static var empty: Rate {
        return Rate(code: "", name: "", rate: 0.0, reciprocalCode: "")
    }
}

extension Rate {
    init?(data: Any, reciprocalCode: String) {
        guard var dictionary = data as? [String: Any] else { return nil }
        dictionary["reciprocalCode"] = reciprocalCode
        self.init(dictionary: dictionary)
    }

    init?(dictionary: Any) {
        guard let dictionary = dictionary as? [String: Any] else { return nil }
        guard let code = dictionary["code"] as? String else { return nil }
        guard let name = dictionary["name"] as? String else { return nil }
        guard let rate = dictionary["rate"] as? Double else { return nil }
        guard let reciprocalCode = dictionary["reciprocalCode"] as? String else { return nil }
        self.init(code: code, name: name, rate: rate, reciprocalCode: reciprocalCode)
    }

    var dictionary: [String: Any] {
        return [
            "code": code,
            "name": name,
            "rate": rate,
            "reciprocalCode": reciprocalCode
        ]
    }
}
