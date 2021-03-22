// 
//  BakingBadAPIRequest.swift
//  breadwallet
//
//  Created by Jared Wheeler on 2/10/21.
//  Copyright © 2021 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import Foundation

public struct BakersRequest: ExternalAPIRequest {
    public typealias Response = [Baker]
    public var hostName: String { return "https://api.baking-bad.org" }
    public var resourceName: String { return "v2/bakers?accuracy=\(accuracy)&timing=\(timing)&health=\(health)" }

    // Parameters
    public let accuracy: String
    public let timing: String
    public let health: String

    // Note that nil parameters will not be used
    public init(accuracy: String = "precise",
                timing: String = "stable,unstable",
                health: String = "active") {
        self.accuracy = accuracy
        self.timing = timing
        self.health = health
    }
}

public struct BakerRequest: ExternalAPIRequest {
    public typealias Response = Baker
    public var hostName: String { return "https://api.baking-bad.org" }
    public var resourceName: String { return "v2/bakers/\(address)" }

    // Parameters
    public let address: String

    public init(address: String) {
        self.address = address
    }
}
