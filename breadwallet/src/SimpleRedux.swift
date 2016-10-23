//
//  SimpleRedux.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-21.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import Foundation

typealias Reducer = (State) -> State

protocol Action {
    var reduce: Reducer { get }
}

//We need reference semantics for Subscribers, so they are restricted to classes
protocol Subscriber: class {}

extension Subscriber {
    var hashValue: Int {
        return ObjectIdentifier(self).hashValue
    }
}

struct State {
    let count: Int
    let isStartFlowVisible: Bool
}

extension State {
    func clone(newCount: Int) -> State {
        return State(count: newCount, isStartFlowVisible: self.isStartFlowVisible)
    }

    func clone(isStartFlowVisible: Bool) -> State {
        return State(count: self.count, isStartFlowVisible: isStartFlowVisible)
    }

    func clone(test: Bool) -> State {
        return State(count: self.count, isStartFlowVisible: test)
    }

    static var initial: State {
        return State(count: 0, isStartFlowVisible: false)
    }
}

typealias StateUpdatedCallback = (State) -> ()

class Store {
    private var state = State.initial {
        didSet {
            subscriptions.forEach { $1(state) }
        }
    }
    private var subscriptions = [Int: StateUpdatedCallback]()

    func perform(action: Action) {
        state = action.reduce(state)
    }

    func subscribe(_ subscriber: Subscriber, callback: @escaping StateUpdatedCallback) {
        subscriptions[subscriber.hashValue] = callback
        callback(state)
    }

    func unsubscribe(_ subscriber: Subscriber) {
        subscriptions.removeValue(forKey: subscriber.hashValue)
    }
}
