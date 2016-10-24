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

struct GranularSubscription<T>{
    let selector: ((State) -> T)
    let callback: (T) -> ()
}

class Store {
    private var state = State.initial {
        didSet {
            granularSubscriptions.forEach {
                //TODO - come up with a more generic way to do this
                switch $1 {
                    case let subscription as GranularSubscription<Int>:
                        updateGranularSubscription(oldState: oldValue, subscription: subscription)
                    case let subscription as GranularSubscription<Bool>:
                        updateGranularSubscription(oldState: oldValue, subscription: subscription)
                    default:
                        print("Warning - unimplemented granulat subscription type")
                }
            }

            subscriptions.forEach { $1(state) }
        }
    }
    private var subscriptions = [Int: StateUpdatedCallback]()
    private var granularSubscriptions = [Int: Any]()

    func perform(action: Action) {
        state = action.reduce(state)
    }

    //Subscription callback is immediately called with current State value on subscription
    //and then any time the selected value changes
    func granularSubscription<T>(_ subscriber: Subscriber, subscription: GranularSubscription<T>) {
        granularSubscriptions[subscriber.hashValue] = subscription
        subscription.callback(subscription.selector(state))
    }

    //Subscription callback is immediately called with current State value on subscription
    //and then any time the entire state changes
    func subscribe(_ subscriber: Subscriber, callback: @escaping StateUpdatedCallback) {
        subscriptions[subscriber.hashValue] = callback
        callback(state)
    }

    func unsubscribe(_ subscriber: Subscriber) {
        subscriptions.removeValue(forKey: subscriber.hashValue)
    }

    private func updateGranularSubscription<T: Equatable>(oldState: State, subscription: GranularSubscription<T>) {
        let newValue = subscription.selector(state)
        if (newValue != subscription.selector(oldState)) {
            subscription.callback(newValue)
        }
    }
}
