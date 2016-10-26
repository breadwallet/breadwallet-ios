//
//  State.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-24.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import Foundation

struct State {
    let isStartFlowVisible: Bool
    let pinCreationStep: PinCreationStep
    let paperPhraseStep: PaperPhraseStep
}

extension State {
    static var initial: State {
        return State(   isStartFlowVisible: false,
                        pinCreationStep:    .none,
                        paperPhraseStep:    .none)
    }
}

enum PinCreationStep {
    case none
    case start
    case confirm(pin: String)
    case confirmFail(pin: String)
    case save(pin: String)
}

enum PaperPhraseStep {
    case none
    case start
    case write
    case confirm
    case save
}


extension PinCreationStep: Equatable {}

func ==(lhs: PinCreationStep, rhs: PinCreationStep) -> Bool {
    switch (lhs, rhs) {
        case (.none, .none):
            return true
        case (.start, .start):
            return true
        case (.confirm(let leftPin), .confirm(let rightPin)):
            return leftPin == rightPin
        case (.save(let leftPin), .save(let rightPin)):
            return leftPin == rightPin
        case (.confirmFail(let leftPin), .confirmFail(let rightPin)):
            return leftPin == rightPin
        default:
            return false
    }
}
