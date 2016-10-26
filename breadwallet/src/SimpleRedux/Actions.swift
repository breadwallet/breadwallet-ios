//
//  Actions.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-22.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import Foundation

struct ShowStartFlow: Action {
    let reduce: Reducer = {
        return $0.clone(isStartFlowVisible: true)
    }
}

struct HideStartFlow: Action {
    let reduce: Reducer = {
        return $0.clone(isStartFlowVisible: false)
    }
}

struct PinCreation {

    struct PinEntryComplete: Action {
        let reduce: Reducer = {
            if $0.pinCreationStep == .start {
                return $0.clone(pinCreationStep: .confirm)
            } else if $0.pinCreationStep == .confirm {
                return $0.clone(pinCreationStep: .save)
            } else {
                assert(false, "warning - invalid state")
            }
        }
    }

    struct Start: Action {
        let reduce: Reducer = {
            return $0.clone(pinCreationStep: .start)
        }
    }

    struct Confirm: Action {
        let reduce: Reducer = {
            return $0.clone(pinCreationStep: .confirm)
        }
    }

    struct Save: Action {
        let reduce: Reducer = {
            return $0.clone(pinCreationStep: .save)
        }
    }
}

extension State {
    func clone(newCount: Int) -> State {
        return State(isStartFlowVisible: self.isStartFlowVisible,
                     pinCreationStep: self.pinCreationStep)
    }

    func clone(isStartFlowVisible: Bool) -> State {
        return State(isStartFlowVisible: isStartFlowVisible,
                     pinCreationStep: self.pinCreationStep)
    }

    func clone(pinCreationStep: PinCreationStep) -> State {
        return State(isStartFlowVisible: self.isStartFlowVisible,
                     pinCreationStep: pinCreationStep)
    }
}
