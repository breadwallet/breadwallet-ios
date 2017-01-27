//
//  Rate.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-01-25.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation

struct Rate {
    let code: String
    let name: String
    let rate: Double
}

extension Rate {
    init?(data: Any) {
        guard let dictionary = data as? [String: Any] else { return nil }
        guard let code = dictionary["code"] as? String else { return nil }
        guard let name = dictionary["name"] as? String else { return nil }
        guard let rate = dictionary["rate"] as? Double else { return nil }
        self.init(code: code, name: name, rate: rate)
    }
}

extension Rate : Equatable {}

func ==(lhs: Rate, rhs: Rate) -> Bool {
    return lhs.code == rhs.code && lhs.name == rhs.name && lhs.rate == rhs.rate
}
