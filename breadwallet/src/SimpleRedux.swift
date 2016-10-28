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

typealias StateUpdatedCallback = (State) -> ()

struct Subscription{
    let selector: ((_ oldState: State, _ newState: State) -> Bool)
    let callback: (State) -> ()
}

class Store {
    private var state = State.initial {
        didSet {
            subscriptions
                .flatMap { $0.value } //Retreive all subscriptions
                .filter { $0.selector(oldValue, state) }
                .forEach { $0.callback(state) }
        }
    }

    private var subscriptions = [Int: [Subscription]]()

    func perform(action: Action) {
        state = action.reduce(state)
    }

    //Subscription callback is immediately called with current State value on subscription
    //and then any time the selected value changes

    //TODO - The callsites of this function could be cleaned up quite a bit if the
    //instantiation of the Subscription struct was brought into this function.
    func subscribe(_ subscriber: Subscriber, subscription: Subscription) {
        let key = subscriber.hashValue
        if subscriptions[key] != nil {
            subscriptions[key]?.append(subscription)
        } else {
            subscriptions[key] = [subscription]
        }
        subscription.callback(state)
    }

    func unsubscribe(_ subscriber: Subscriber) {
        subscriptions.removeValue(forKey: subscriber.hashValue)
    }

}
