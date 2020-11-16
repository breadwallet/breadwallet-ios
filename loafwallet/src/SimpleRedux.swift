//
//  SimpleRedux.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-21.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

typealias Reducer = (ReduxState) -> ReduxState
typealias Selector = (_ oldState: ReduxState, _ newState: ReduxState) -> Bool

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

typealias StateUpdatedCallback = (ReduxState) -> Void

struct Subscription {
    let selector: ((_ oldState: ReduxState, _ newState: ReduxState) -> Bool)
    let callback: (ReduxState) -> Void
}

struct Trigger {
    let name: TriggerName
    let callback: (TriggerName?) -> Void
}

enum TriggerName {
    case presentFaq(String)
    case registerForPushNotificationToken
    case retrySync
    case rescan
    case lock
    case promptBiometrics
    case promptPaperKey
    case promptUpgradePin
    case loginFromSend
    case blockModalDismissal
    case unblockModalDismissal
    case openFile(Data)
    case recommendRescan
    case receivedPaymentRequest(PaymentRequest?)
    case scanQr
    case copyWalletAddresses(String?, String?)
    case authenticateForBitId(String, (BitIdAuthResult)->Void)
    case hideStatusBar
    case showStatusBar
    case lightWeightAlert(String)
    case didCreateOrRecoverWallet
    case showAlert(UIAlertController?)
    case reinitWalletManager((()->Void)?)
    case didUpgradePin
    case txMemoUpdated(String)
    case promptShareData
    case didEnableShareData
    case didWritePaperKey
} //NB : remember to add to triggers to == fuction below

extension TriggerName : Equatable {}

func ==(lhs: TriggerName, rhs: TriggerName) -> Bool {
    switch (lhs, rhs) {
    case (.presentFaq(_), .presentFaq(_)):
        return true
    case (.registerForPushNotificationToken, .registerForPushNotificationToken):
        return true
    case (.retrySync, .retrySync):
        return true
    case (.rescan, .rescan):
        return true
    case (.lock, .lock):
        return true
    case (.promptBiometrics, .promptBiometrics):
        return true
    case (.promptPaperKey, .promptPaperKey):
        return true
    case (.promptUpgradePin, .promptUpgradePin):
        return true
    case (.loginFromSend, .loginFromSend):
        return true
    case (.blockModalDismissal, .blockModalDismissal):
        return true
    case (.unblockModalDismissal, .unblockModalDismissal):
        return true
    case (.openFile(_), .openFile(_)):
        return true
    case (.recommendRescan, .recommendRescan):
        return true
    case (.receivedPaymentRequest(_), .receivedPaymentRequest(_)):
        return true
    case (.scanQr, .scanQr):
        return true
    case (.copyWalletAddresses(_,_), .copyWalletAddresses(_,_)):
        return true
    case (.authenticateForBitId(_,_), .authenticateForBitId(_,_)):
        return true
    case (.showStatusBar, .showStatusBar):
        return true
    case (.hideStatusBar, .hideStatusBar):
        return true
    case (.lightWeightAlert(_), .lightWeightAlert(_)):
        return true
    case (.didCreateOrRecoverWallet, .didCreateOrRecoverWallet):
        return true
    case (.showAlert(_), .showAlert(_)):
        return true
    case (.reinitWalletManager(_), .reinitWalletManager(_)):
        return true
    case (.didUpgradePin, .didUpgradePin):
        return true
    case (.txMemoUpdated(_), .txMemoUpdated(_)):
        return true
    case (.promptShareData, .promptShareData):
        return true
    case (.didEnableShareData, .didEnableShareData):
        return true
    case (.didWritePaperKey, .didWritePaperKey):
        return true
    default:
        return false
    }
}

class Store {

    //MARK: - Public
    func perform(action: Action) {
        state = action.reduce(state)
    }

    func trigger(name: TriggerName) {
        triggers
            .flatMap { $0.value }
            .filter { $0.name == name }
            .forEach { $0.callback(name) }
    }

    //Subscription callback is immediately called with current State value on subscription
    //and then any time the selected value changes
    func subscribe(_ subscriber: Subscriber, selector: @escaping Selector, callback: @escaping (ReduxState) -> Void) {
        lazySubscribe(subscriber, selector: selector, callback: callback)
        callback(state)
    }

    //Same as subscribe(), but doesn't call the callback with current state upon subscription
    func lazySubscribe(_ subscriber: Subscriber, selector: @escaping Selector, callback: @escaping (ReduxState) -> Void) {
        let key = subscriber.hashValue
        let subscription = Subscription(selector: selector, callback: callback)
        if subscriptions[key] != nil {
            subscriptions[key]?.append(subscription)
        } else {
            subscriptions[key] = [subscription]
        }
    }

    func subscribe(_ subscriber: Subscriber, name: TriggerName, callback: @escaping (TriggerName?) -> Void) {
        let key = subscriber.hashValue
        let trigger = Trigger(name: name, callback: callback)
        if triggers[key] != nil {
            triggers[key]?.append(trigger)
        } else {
            triggers[key] = [trigger]
        }
    }

    func unsubscribe(_ subscriber: Subscriber) {
        subscriptions.removeValue(forKey: subscriber.hashValue)
        triggers.removeValue(forKey: subscriber.hashValue)
    }

    //MARK: - Private
    private(set) var state = ReduxState.initial {
        didSet {
            subscriptions
                .flatMap { $0.value } //Retreive all subscriptions (subscriptions is a dictionary)
                .filter { $0.selector(oldValue, state) }
                .forEach { $0.callback(state) }
        }
    }

    func removeAllSubscriptions() {
        subscriptions.removeAll()
        triggers.removeAll()
    }

    private var subscriptions: [Int: [Subscription]] = [:]
    private var triggers: [Int: [Trigger]] = [:]
}
