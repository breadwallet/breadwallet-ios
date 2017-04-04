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
}
