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
