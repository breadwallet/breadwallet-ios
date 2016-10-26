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
        let reduce: Reducer

        init(newPin: String) {
            reduce = {
                switch $0.pinCreationStep {
                    case .start:
                        return $0.clone(pinCreationStep: .confirm(pin: newPin))
                    case .confirm(let previousPin):
                        return stateForNewPin(newPin: newPin, previousPin: previousPin, state: $0)
                    case .confirmFail(let previousPin):
                        return stateForNewPin(newPin: newPin, previousPin: previousPin, state: $0)
                    default:
                        assert(false, "Warning - invalid state")
                }
            }
        }
    }

    struct Start: Action {
        let reduce: Reducer = {
            return $0.clone(pinCreationStep: .start)
        }
    }
}

fileprivate func stateForNewPin(newPin: String, previousPin: String, state: State) -> State {
    if newPin == previousPin {
        return state.clone(pinCreationStep: .save(pin: newPin))
    } else {
        return state.clone(pinCreationStep: .confirmFail(pin: previousPin))
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
