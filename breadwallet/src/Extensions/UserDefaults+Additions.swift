//
//  UserDefaults+Additions.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-04-04.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation

private let defaults = UserDefaults.standard
private let isTouchIdEnabledKey = "istouchidenabled"
private let defaultCurrencyKey = "defaultcurrency"

extension UserDefaults {

    static var isTouchIdEnabled: Bool {
        get {
            guard defaults.object(forKey: isTouchIdEnabledKey) != nil else {
                return false
            }
            return defaults.bool(forKey: isTouchIdEnabledKey)
        }
        set {
            defaults.set(newValue, forKey: isTouchIdEnabledKey)
        }
    }

    static var defaultCurrency: String {
        get {
            guard defaults.object(forKey: defaultCurrencyKey) != nil else {
                return  Locale.current.currencyCode ?? "USD"
            }
            return defaults.string(forKey: defaultCurrencyKey)!
        }
        set {
            defaults.set(newValue, forKey: defaultCurrencyKey)
        }
    }
}
