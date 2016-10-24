//
//  Actions.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-22.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import Foundation

struct IncrementImportantValue: Action {
    let reduce: Reducer = {
        return $0.clone(newCount: $0.count + 1)
    }
}

struct DecrementImportantValue: Action {
    let reduce: Reducer = {
        return $0.clone(newCount: $0.count - 1)
    }
}

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
        return State(count: newCount,
                     isStartFlowVisible: self.isStartFlowVisible,
                     pinCreationStep: self.pinCreationStep)
    }

    func clone(isStartFlowVisible: Bool) -> State {
        return State(count: self.count,
                     isStartFlowVisible: isStartFlowVisible,
                     pinCreationStep: self.pinCreationStep)
    }

    func clone(pinCreationStep: PinCreationStep) -> State {
        return State(count: self.count,
                     isStartFlowVisible: self.isStartFlowVisible,
                     pinCreationStep: pinCreationStep)
    }
}
