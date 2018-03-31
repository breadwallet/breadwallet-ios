//
//  Actions.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-22.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit
import BRCore

struct StateChange : Action {
    let reduce: Reducer
    init(_ state: State) {
        reduce = { _ in return state }
    }
}

//MARK: - Startup Modals
struct ShowStartFlow : Action {
    let reduce: Reducer = {
        return $0.mutate(isStartFlowVisible: true)
    }
}

struct HideStartFlow : Action {
    let reduce: Reducer = { state in
        return state.mutate(isStartFlowVisible: false, rootModal: .none)
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
struct WalletChange: Trackable {
    struct WalletAction: Action {
        let reduce: Reducer
    }
    
    let currency: CurrencyDef
    
    init(_ currency: CurrencyDef) {
        self.currency = currency
    }
    
    func setProgress(progress: Double, timestamp: UInt32) -> WalletAction {
        return WalletAction(reduce: { $0.mutate(walletState: $0[self.currency].mutate(syncProgress: progress, lastBlockTimestamp: timestamp)) })
    }
    func setSyncingState(_ syncState: SyncState) -> WalletAction {
        return WalletAction(reduce: { $0.mutate(walletState: $0[self.currency].mutate(syncState: syncState)) })
    }
    func setBalance(_ balance: UInt256) -> WalletAction {
        return WalletAction(reduce: { $0.mutate(walletState: $0[self.currency].mutate(balance: balance)) })
    }
    func setTransactions(_ transactions: [Transaction]) -> WalletAction {
        return WalletAction(reduce: { $0.mutate(walletState: $0[self.currency].mutate(transactions: transactions)) })
    }
    func setWalletName(_ name: String) -> WalletAction {
        return WalletAction(reduce: { $0.mutate(walletState: $0[self.currency].mutate(name: name)) })
    }
    func setWalletCreationDate(_ date: Date) -> WalletAction {
        return WalletAction(reduce: { $0.mutate(walletState: $0[self.currency].mutate(creationDate: date)) })
    }
    func setIsRescanning(_ isRescanning: Bool) -> WalletAction {
        return WalletAction(reduce: { $0.mutate(walletState: $0[self.currency].mutate(isRescanning: isRescanning)) })
    }
    
    func setExchangeRates(currentRate: Rate, rates: [Rate]) -> WalletAction {
        UserDefaults.setCurrentRateData(newValue: currentRate.dictionary, forCode: currentRate.reciprocalCode)

        return WalletAction(reduce: { $0.mutate(walletState: $0[self.currency].mutate(currentRate: currentRate, rates: rates)) })
    }
    
    func setExchangeRate(_ currentRate: Rate) -> WalletAction {
        return WalletAction(reduce: { $0.mutate(walletState: $0[self.currency].mutate(currentRate: currentRate)) })
    }
    
    func setFees(_ fees: Fees) -> WalletAction {
        return WalletAction(reduce: { $0.mutate(walletState: $0[self.currency].mutate(fees: fees)) })
    }
    
    func setRecommendScan(_ recommendRescan: Bool) -> WalletAction {
        saveEvent("event.recommendRescan")
        return WalletAction(reduce: { $0.mutate(walletState: $0[self.currency].mutate(recommendRescan: recommendRescan)) })
    }

    func setMaxDigits(_ maxDigits: Int) -> WalletAction {
        if !self.currency.matches(Currencies.eth) {
            UserDefaults.maxDigits = maxDigits
        }
        saveEvent("maxDigits.set", attributes: ["maxDigits": "\(maxDigits)"])
        return WalletAction(reduce: { $0.mutate(walletState: $0[self.currency].mutate(maxDigits: maxDigits)) })
    }
    
    func set(_ walletState: WalletState) -> WalletAction {
        return WalletAction(reduce: { $0.mutate(walletState: walletState)})
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

//MARK: - Alerts
enum Alert {
    struct Show : Action {
        let reduce: Reducer
        init(_ type: AlertType) {
            reduce = { $0.mutate(alert: type) }
        }
    }
    struct Hide : Action {
        let reduce: Reducer = {
            let newState = $0.mutate(alert: AlertType.none)
            return newState
        }
    }
}

enum Biometrics {
    struct setIsEnabled : Action, Trackable {
        let reduce: Reducer
        init(_ isBiometricsEnabled: Bool) {
            UserDefaults.isBiometricsEnabled = isBiometricsEnabled
            reduce = { $0.mutate(isBiometricsEnabled: isBiometricsEnabled) }
            saveEvent("event.enableBiometrics", attributes: ["isEnabled": "\(isBiometricsEnabled)"])
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

enum PushNotifications {
    struct setIsEnabled : Action {
        let reduce: Reducer
        init(_ isEnabled: Bool) {
            reduce = { $0.mutate(isPushNotificationsEnabled: isEnabled) }
        }
    }
}

enum biometricsActions {
    struct setIsPrompting : Action {
        let reduce: Reducer
        init(_ isPrompting: Bool) {
            reduce = { $0.mutate(isPromptingBiometrics: isPrompting) }
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
