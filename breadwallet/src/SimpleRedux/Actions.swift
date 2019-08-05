//
//  Actions.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-22.
//  Copyright © 2016-2019 Breadwinner AG. All rights reserved.
//

import UIKit

// MARK: - Startup Modals
struct Reset: Action {
    let reduce: Reducer = { _ in
        return State.initial.mutate(isLoginRequired: false)
    }
}

struct RequireLogin: Action {
    let reduce: Reducer = {
        return $0.mutate(isLoginRequired: true)
    }
}

struct LoginSuccess: Action {
    let reduce: Reducer = {
        return $0.mutate(isLoginRequired: false)
    }
}

// MARK: - Root Modals
struct RootModalActions {
    struct Present: Action {
        let reduce: Reducer
        init(modal: RootModal) {
            reduce = { $0.mutate(rootModal: modal) }
        }
    }
}

enum ManageWallets {

    struct SetWallets: Action {
        let reduce: Reducer
        init(_ newWallets: [String: WalletState]) {
            reduce = {
                return $0.mutate(wallets: newWallets)
            }
        }
    }

    struct AddWallets: Action {
        let reduce: Reducer
        init(_ newWallets: [String: WalletState]) {
            reduce = {
                return $0.mutate(wallets: $0.wallets.merging(newWallets) { (x, _) in x })
            }
        }
    }
    
    struct HideWalletAtIndex: Action {
        let reduce: Reducer
        init(_ index: Int) {
            reduce = {
                var newWallets = $0.wallets
                guard $0.orderedWallets.count > index else { return $0 }
                newWallets[$0.orderedWallets[index].currency.uid] = nil
                return $0.mutate(wallets: newWallets)
            }
        }
    }
    
    struct MoveWalletFrom: Action {
        let reduce: Reducer
        init(_ from: Int, to: Int) {
            reduce = {
                var orderedWallets = $0.orderedWallets
                guard orderedWallets.indices.contains(to),
                    orderedWallets.indices.contains(from) else { return $0 }
                orderedWallets.insert(orderedWallets.remove(at: from), at: to)
                var i = 0
                let newWallets = orderedWallets.reduce(into: [String: WalletState](), { dict, wallet in
                    dict[wallet.currency.uid] = wallet.mutate(displayOrder: i)
                    i += 1
                })
                return $0.mutate(wallets: newWallets)
            }
        }
    }
}

// MARK: - Wallet State
struct WalletChange: Trackable {
    struct WalletAction: Action {
        let reduce: Reducer
    }
    
    let currency: Currency
    
    init(_ currency: Currency) {
        self.currency = currency
    }
    
    func setProgress(progress: Double, timestamp: UInt32) -> WalletAction {
        return WalletAction(reduce: {
            guard let state = $0[self.currency] else { return $0 }
            return $0.mutate(walletState: state.mutate(syncProgress: progress, lastBlockTimestamp: timestamp)) })
    }
    func setSyncingState(_ syncState: SyncState) -> WalletAction {
        return WalletAction(reduce: {
            guard let state = $0[self.currency] else { return $0 }
            return $0.mutate(walletState: state.mutate(syncState: syncState)) })
    }
    func setBalance(_ balance: Amount) -> WalletAction {
        return WalletAction(reduce: {
            guard let walletState = $0[self.currency] else { return $0 }
            return $0.mutate(walletState: walletState.mutate(balance: balance)) })
    }
    
    func setExchangeRates(currentRate: Rate, rates: [Rate]) -> WalletAction {
        UserDefaults.setCurrentRateData(newValue: currentRate.dictionary, forCode: currentRate.reciprocalCode)
        return WalletAction(reduce: {
            guard let state = $0[self.currency] else { return $0 }
            return $0.mutate(walletState: state.mutate(currentRate: currentRate, rates: rates)) })
    }
    
    func setExchangeRate(_ currentRate: Rate) -> WalletAction {
        return WalletAction(reduce: {
            guard let state = $0[self.currency] else { return $0 }
            return $0.mutate(walletState: state.mutate(currentRate: currentRate)) })
    }
    
    func set(_ walletState: WalletState) -> WalletAction {
        return WalletAction(reduce: { $0.mutate(walletState: walletState)})
    }
    
    func setPriceChange(_ priceChange: PriceChange) -> WalletAction {
        return WalletAction(reduce: {
            guard let state = $0[self.currency] else { return $0 }
            return $0.mutate(walletState: state.mutate(priceChange: priceChange))
        })
    }
}

// MARK: - Currency
enum CurrencyChange {
    struct Toggle: Action {
        let reduce: Reducer = {
            UserDefaults.showFiatAmounts = !$0.showFiatAmounts
            return $0.mutate(showFiatAmounts: !$0.showFiatAmounts)
        }
    }

    struct SetShowFiatAmounts: Action {
        let reduce: Reducer
        init(_ showFiatAmounts: Bool) {
            reduce = { $0.mutate(showFiatAmounts: showFiatAmounts) }
        }
    }
}

// MARK: - Alerts
enum Alert {
    struct Show: Action {
        let reduce: Reducer
        init(_ type: AlertType) {
            reduce = { $0.mutate(alert: type) }
        }
    }
    struct Hide: Action {
        let reduce: Reducer = {
            let newState = $0.mutate(alert: AlertType.none)
            return newState
        }
    }
}

enum Biometrics {
    
    struct SetIsEnabledForUnlocking: Action, Trackable {
        let reduce: Reducer
        init(_ isBiometricsEnabled: Bool) {
            UserDefaults.isBiometricsEnabled = isBiometricsEnabled
            reduce = { $0.mutate(isBiometricsEnabled: isBiometricsEnabled) }
            saveEvent("event.enableBiometrics", attributes: ["isEnabled": "\(isBiometricsEnabled)", "type": "unlock"])
        }
    }
    
    struct SetIsEnabledForTransactions: Action, Trackable {
        let reduce: Reducer
        init(_ isBiometricsEnabledForTransactions: Bool) {
            UserDefaults.isBiometricsEnabledForTransactions = isBiometricsEnabledForTransactions
            reduce = { $0.mutate(isBiometricsEnabledForTransactions: isBiometricsEnabledForTransactions) }
            saveEvent("event.enableBiometrics", attributes: ["isEnabled": "\(isBiometricsEnabledForTransactions)", "type": "sending"])
        }
    }
}

enum DefaultCurrency {
    struct SetDefault: Action, Trackable {
        let reduce: Reducer
        init(_ defaultCurrencyCode: String) {
            UserDefaults.defaultCurrencyCode = defaultCurrencyCode
            reduce = { $0.mutate(defaultCurrencyCode: defaultCurrencyCode) }
            saveEvent("event.setDefaultCurrency", attributes: ["code": defaultCurrencyCode])
        }
    }
}

enum PushNotifications {
    struct SetIsEnabled: Action {
        let reduce: Reducer
        init(_ isEnabled: Bool) {
            reduce = { $0.mutate(isPushNotificationsEnabled: isEnabled) }
        }
    }
}

enum BiometricsActions {
    struct SetIsPrompting: Action {
        let reduce: Reducer
        init(_ isPrompting: Bool) {
            reduce = { $0.mutate(isPromptingBiometrics: isPrompting) }
        }
    }
}

enum PinLength {
    struct Set: Action {
        let reduce: Reducer
        init(_ pinLength: Int) {
            reduce = { $0.mutate(pinLength: pinLength) }
        }
    }
}

enum WalletID {
    struct Set: Action {
        let reduce: Reducer
        init(_ walletID: String?) {
            reduce = { $0.mutate(walletID: walletID) }
        }
    }
}

enum AccountChange {
    struct SetName: Action {
        let reduce: Reducer
        init(_ name: String) {
            reduce = { $0.mutate(accountName: name) }
        }
    }
    struct SetCreationDate: Action {
        let reduce: Reducer
        init(_ date: Date) {
            reduce = { $0.mutate(creationDate: date) }
        }
    }
}
