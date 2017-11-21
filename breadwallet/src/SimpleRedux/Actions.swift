//
//  Actions.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-22.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

//MARK: - Startup Modals
struct ShowStartFlow : Action {
    let reduce: Reducer = {
        return $0.mutate(isStartFlowVisible: true)
    }
}

struct HideStartFlow : Action {
    let reduce: Reducer = { state in
        return State(isStartFlowVisible: false,
                     isLoginRequired: state.isLoginRequired,
                     rootModal: .none,
                     walletState: state.walletState,
                     isBtcSwapped: state.isBtcSwapped,
                     currentRate: state.currentRate,
                     rates: state.rates,
                     alert: state.alert,
                     isTouchIdEnabled: state.isTouchIdEnabled,
                     defaultCurrencyCode: state.defaultCurrencyCode,
                     recommendRescan: state.recommendRescan,
                     isLoadingTransactions: state.isLoadingTransactions,
                     maxDigits: state.maxDigits,
                     isPushNotificationsEnabled: state.isPushNotificationsEnabled,
                     isPromptingTouchId: state.isPromptingTouchId,
                     pinLength: state.pinLength,
                     fees: state.fees,
                     currency: state.currency)
    }
}

struct Reset : Action {
    let reduce: Reducer = { _ in
        return State.initial.mutate(isLoginRequired: false)
    }
}

struct RequireLogin : Action {
    let reduce: Reducer = {
        return $0.mutate(isLoginRequired: true)
    }
}

struct LoginSuccess : Action {
    let reduce: Reducer = {
        return $0.mutate(isLoginRequired: false)
    }
}

//MARK: - Root Modals
struct RootModalActions {
    struct Present: Action {
        let reduce: Reducer
        init(modal: RootModal) {
            reduce = { $0.mutate(rootModal: modal) }
        }
    }
}

//MARK: - Wallet State
enum WalletChange {
    struct setProgress: Action {
        let reduce: Reducer
        init(progress: Double, timestamp: UInt32) {
            reduce = { $0.mutate(walletState: $0.walletState.mutate(syncProgress: progress, lastBlockTimestamp: timestamp)) }
        }
    }
    struct setSyncingState: Action {
        let reduce: Reducer
        init(_ syncState: SyncState) {
            reduce = { $0.mutate(walletState: $0.walletState.mutate(syncState: syncState)) }
        }
    }
    struct setBalance: Action {
        let reduce: Reducer
        init(_ balance: UInt64) {
            reduce = { $0.mutate(walletState: $0.walletState.mutate(balance: balance)) }
        }
    }
    struct setTransactions: Action {
        let reduce: Reducer
        init(_ transactions: [Transaction]) {
            reduce = { $0.mutate(walletState: $0.walletState.mutate(transactions: transactions)) }
        }
    }
    struct setWalletName: Action {
        let reduce: Reducer
        init(_ name: String) {
            reduce = { $0.mutate(walletState: $0.walletState.mutate(name: name)) }
        }
    }
    struct setWalletCreationDate: Action {
        let reduce: Reducer
        init(_ date: Date) {
            reduce = { $0.mutate(walletState: $0.walletState.mutate(creationDate: date)) }
        }
    }
    struct setIsRescanning: Action {
        let reduce: Reducer
        init(_ isRescanning: Bool) {
            reduce = { $0.mutate(walletState: $0.walletState.mutate(isRescanning: isRescanning)) }
        }
    }
    struct set : Action {
        let reduce: Reducer
        init(_ walletState: WalletState) {
            reduce = { $0.mutate(walletState: walletState) }
        }
    }
}

//MARK: - Currency
enum CurrencyChange {
    struct toggle: Action {
        let reduce: Reducer = {
            UserDefaults.isBtcSwapped = !$0.isBtcSwapped
            return $0.mutate(isBtcSwapped: !$0.isBtcSwapped)
        }
    }

    struct setIsSwapped: Action {
        let reduce: Reducer
        init(_ isBtcSwapped: Bool) {
            reduce = { $0.mutate(isBtcSwapped: isBtcSwapped) }
        }
    }
}

//MARK: - Exchange Rates
enum ExchangeRates {
    struct setRates : Action {
        let reduce: Reducer
        init(currentRate: Rate, rates: [Rate] ) {
            UserDefaults.currentRateData = currentRate.dictionary
            reduce = { $0.mutate(currentRate: currentRate, rates: rates) }
        }
    }
    struct setRate: Action {
        let reduce: Reducer
        init(_ currentRate: Rate) {
            reduce = { $0.mutate(currentRate: currentRate) }
        }
    }
}

//MARK: - Alerts
enum Alert {
    struct Show : Action {
        let reduce: Reducer
        init(_ type: AlertType) {
            reduce = { $0.mutate(alert: type) }
        }
    }
    struct Hide : Action {
        let reduce: Reducer = { $0.mutate(alert: nil) }
    }
}

enum TouchId {
    struct setIsEnabled : Action, Trackable {
        let reduce: Reducer
        init(_ isTouchIdEnabled: Bool) {
            UserDefaults.isTouchIdEnabled = isTouchIdEnabled
            reduce = { $0.mutate(isTouchIdEnabled: isTouchIdEnabled) }
            saveEvent("event.enableTouchId", attributes: ["isEnabled": "\(isTouchIdEnabled)"])
        }
    }
}

enum DefaultCurrency {
    struct setDefault : Action, Trackable {
        let reduce: Reducer
        init(_ defaultCurrencyCode: String) {
            UserDefaults.defaultCurrencyCode = defaultCurrencyCode
            reduce = { $0.mutate(defaultCurrencyCode: defaultCurrencyCode) }
            saveEvent("event.setDefaultCurrency", attributes: ["code": defaultCurrencyCode])
        }
    }
}

enum RecommendRescan {
    struct set : Action, Trackable {
        let reduce: Reducer
        init(_ recommendRescan: Bool) {
            reduce = { $0.mutate(recommendRescan: recommendRescan) }
            saveEvent("event.recommendRescan")
        }
    }
}

enum LoadTransactions {
    struct set : Action {
        let reduce: Reducer
        init(_ isLoadingTransactions: Bool) {
            reduce = { $0.mutate(isLoadingTransactions: isLoadingTransactions) }
        }
    }
}

enum MaxDigits {
    struct set : Action, Trackable {
        let reduce: Reducer
        init(_ maxDigits: Int) {
            UserDefaults.maxDigits = maxDigits
            reduce = { $0.mutate(maxDigits: maxDigits)}
            saveEvent("maxDigits.set", attributes: ["maxDigits": "\(maxDigits)"])
        }
    }
}

enum PushNotifications {
    struct setIsEnabled : Action {
        let reduce: Reducer
        init(_ isEnabled: Bool) {
            reduce = { $0.mutate(isPushNotificationsEnabled: isEnabled) }
        }
    }
}

enum TouchIdActions {
    struct setIsPrompting : Action {
        let reduce: Reducer
        init(_ isPrompting: Bool) {
            reduce = { $0.mutate(isPromptingTouchId: isPrompting) }
        }
    }
}

enum PinLength {
    struct set : Action {
        let reduce: Reducer
        init(_ pinLength: Int) {
            reduce = { $0.mutate(pinLength: pinLength) }
        }
    }
}

enum UpdateFees {
    struct set : Action {
        let reduce: Reducer
        init(_ fees: Fees) {
            reduce = { $0.mutate(fees: fees) }
        }
    }
}

enum CurrencyActions {
    struct set : Action {
        let reduce: Reducer
        init(_ currency: Currency) {
            reduce = { $0.mutate(currency: currency) }
        }
    }
}
