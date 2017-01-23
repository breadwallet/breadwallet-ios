//
//  SimpleRedux.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-21.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

typealias Reducer = (State) -> State
typealias Selector = (_ oldState: State, _ newState: State) -> Bool

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

    init() {
        addPasteboardSubscriptions()
    }

    func perform(action: Action) {
        state = action.reduce(state)
    }

    //Subscription callback is immediately called with current State value on subscription
    //and then any time the selected value changes
    func subscribe(_ subscriber: Subscriber, selector: @escaping Selector, callback: @escaping (State) -> ()) {
        let key = subscriber.hashValue
        let subscription = Subscription(selector: selector, callback: callback)
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

    private(set) var state = State.initial {
        didSet {
            subscriptions
                .flatMap { $0.value } //Retreive all subscriptions (subscriptions is a dictionary)
                .filter { $0.selector(oldValue, state) }
                .forEach { $0.callback(state) }
        }
    }

    private var subscriptions = [Int: [Subscription]]()

    private func addPasteboardSubscriptions() {
        NotificationCenter.default.addObserver(forName: .UIPasteboardChanged, object: nil, queue: nil, using: { note in
            self.perform(action: Pasteboard.refresh())
        })

        NotificationCenter.default.addObserver(forName: .UIApplicationDidBecomeActive, object: nil, queue: OperationQueue(), using: { note in
            self.perform(action: Pasteboard.refresh())
        })
    }
}
