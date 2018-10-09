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

typealias StateUpdatedCallback = (State) -> Void

struct Subscription {
    let selector: ((_ oldState: State, _ newState: State) -> Bool)
    let callback: (State) -> Void
}

struct Trigger {
    let name: TriggerName
    let callback: (TriggerName?) -> Void
}

enum TriggerName {
    case presentFaq(String, CurrencyDef?)
    case registerForPushNotificationToken
    case retrySync(CurrencyDef)
    case rescan(CurrencyDef)
    case lock
    case promptBiometrics
    case promptPaperKey
    case promptUpgradePin
    case loginFromSend
    case blockModalDismissal
    case unblockModalDismissal
    case openFile(Data)
    case recommendRescan(CurrencyDef)
    case receivedPaymentRequest(PaymentRequest?)
    case scanQr
    case copyWalletAddresses(String?, String?)
    case authenticateForPlatform(String, Bool, (PlatformAuthResult)->Void) // (prompt, allowBiometricAuth, callback)
    case confirmTransaction(CurrencyDef, Amount, Amount, String, (Bool)->Void) // currency, amount, fee, address, callback
    case hideStatusBar
    case showStatusBar
    case lightWeightAlert(String)
    case didCreateOrRecoverWallet
    case showAlert(UIAlertController?)
    case reinitWalletManager((()->Void)?)
    case didUpgradePin
    case txMemoUpdated(String)
    case promptShareData
    case didWritePaperKey
    case wipeWalletNoPrompt
    case didUpdateFeatureFlags
    case showCurrency(CurrencyDef)
    case resetDisplayCurrencies
    case promptLinkWallet(WalletPairingRequest)
    case linkWallet(WalletPairingRequest, Bool, PairingCompletionHandler) // request, accepted, callback
    case fetchInbox
} //NB : remember to add to triggers to == fuction below

extension TriggerName : Equatable {}

func ==(lhs: TriggerName, rhs: TriggerName) -> Bool {
    switch (lhs, rhs) {
    case (.presentFaq(_,_), .presentFaq(_,_)):
        return true
    case (.registerForPushNotificationToken, .registerForPushNotificationToken):
        return true
    case (.retrySync(let lhsCurrency), .retrySync(let rhsCurrency)):
        return lhsCurrency.code == rhsCurrency.code
    case (.rescan(let lhsCurrency), .rescan(let rhsCurrency)):
        return lhsCurrency.code == rhsCurrency.code
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
    case (.recommendRescan(let lhsCurrency), .recommendRescan(let rhsCurrency)):
        return lhsCurrency.code == rhsCurrency.code
    case (.receivedPaymentRequest(_), .receivedPaymentRequest(_)):
        return true
    case (.scanQr, .scanQr):
        return true
    case (.copyWalletAddresses(_,_), .copyWalletAddresses(_,_)):
        return true
    case (.authenticateForPlatform(_,_,_), .authenticateForPlatform(_,_,_)):
        return true
    case (.confirmTransaction(_,_,_,_,_), .confirmTransaction(_,_,_,_,_)):
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
    case (.didWritePaperKey, .didWritePaperKey):
        return true
    case (.wipeWalletNoPrompt, .wipeWalletNoPrompt):
        return true
    case (.didUpdateFeatureFlags, .didUpdateFeatureFlags):
        return true
    case (.showCurrency(_), .showCurrency(_)):
        return true
    case (.resetDisplayCurrencies, .resetDisplayCurrencies):
        return true
    case (.promptLinkWallet(_), .promptLinkWallet(_)):
        return true
    case (.linkWallet(_,_,_), .linkWallet(_,_,_)):
        return true
    case (.fetchInbox, .fetchInbox):
        return true
    default:
        return false
    }
}

class Store {

    private static let shared = Store()
    private init() { }
    
    private var isClearingSubscriptions = false

    //MARK: - Public
    static func perform(action: Action) {
        Store.shared.perform(action: action)
    }

    static func trigger(name: TriggerName) {
        Store.shared.trigger(name: name)
    }

    static var state: State {
        return shared.state
    }

    static func subscribe(_ subscriber: Subscriber, selector: @escaping Selector, callback: @escaping (State) -> Void) {
        Store.shared.subscribe(subscriber, selector: selector, callback: callback)
    }

    static func subscribe(_ subscriber: Subscriber, name: TriggerName, callback: @escaping (TriggerName?) -> Void) {
        Store.shared.subscribe(subscriber, name: name, callback: callback)
    }

    static func lazySubscribe(_ subscriber: Subscriber, selector: @escaping Selector, callback: @escaping (State) -> Void) {
        Store.shared.lazySubscribe(subscriber, selector: selector, callback: callback)
    }

    static func unsubscribe(_ subscriber: Subscriber) {
        Store.shared.unsubscribe(subscriber)
    }

    static func removeAllSubscriptions() {
        Store.shared.removeAllSubscriptions()
    }

    //MARK: - Private
    func perform(action: Action) {
        assert(Thread.isMainThread)
        state = action.reduce(state)
    }

    func trigger(name: TriggerName) {
        triggers
            .flatMap { $0.value }
            .filter { $0.name == name }
            .forEach { trigger in
                DispatchQueue.main.async {
                    trigger.callback(name)
                }
        }
    }

    //Subscription callback is immediately called with current State value on subscription
    //and then any time the selected value changes
    func subscribe(_ subscriber: Subscriber, selector: @escaping Selector, callback: @escaping (State) -> Void) {
        lazySubscribe(subscriber, selector: selector, callback: callback)
        callback(state)
    }

    //Same as subscribe(), but doesn't call the callback with current state upon subscription
    func lazySubscribe(_ subscriber: Subscriber, selector: @escaping Selector, callback: @escaping (State) -> Void) {
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
        guard !isClearingSubscriptions else { return }
        self.subscriptions.removeValue(forKey: subscriber.hashValue)
        self.triggers.removeValue(forKey: subscriber.hashValue)
    }

    //MARK: - Private
    private(set) var state = State.initial {
        didSet {
            subscriptions
                .flatMap { $0.value } //Retreive all subscriptions (subscriptions is a dictionary)
                .filter { $0.selector(oldValue, state) }
                .forEach { subscription in
                    DispatchQueue.main.async {
                        subscription.callback(self.state)
                    }
            }
        }
    }

    func removeAllSubscriptions() {
        DispatchQueue.main.async {
            // removing the subscription may trigger deinit of the object and a duplicate call to unsubscribe
            self.isClearingSubscriptions = true
            self.subscriptions.removeAll()
            self.triggers.removeAll()
        }
    }

    private var subscriptions: [Int: [Subscription]] = [:]
    private var triggers: [Int: [Trigger]] = [:]
}
