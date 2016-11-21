//
//  Trackable.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-11-20.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import Foundation

protocol Trackable {
    func saveEvent(_ eventName: String)
    func saveEvent(_ eventName: String, attributes: [String: String])
}
