//
//  State.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-24.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import Foundation

struct State {
    let count: Int
    let isStartFlowVisible: Bool
    let pinCreation: PinCreationState?
}

extension State {
    static var initial: State {
        return State(   count:              0,
                        isStartFlowVisible: false,
                        pinCreation:        nil)
    }
}

enum PinCreationState {
    case start
    case confirm
    case save
}
