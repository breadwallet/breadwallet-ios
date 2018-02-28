//
//  State.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-24.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit
import BRCore

struct State {
    let isStartFlowVisible: Bool
    let isLoginRequired: Bool
    let rootModal: RootModal
    let isBtcSwapped: Bool //move to CurrencyState
    let alert: AlertType?
    let isBiometricsEnabled: Bool
    let defaultCurrencyCode: String
    let isPushNotificationsEnabled: Bool
    let isPromptingBiometrics: Bool
    let pinLength: Int
    let wallets: [String: WalletState]
    
    subscript(currency: CurrencyDef) -> WalletState {
        guard let walletState = wallets[currency.code] else {
            // this should never happen as long as all currencies in use are initialized in State.initial
            fatalError("unsupported currency!")
        }
        return walletState
    }
    
    var orderedWallets: [WalletState] {
        return wallets.values.sorted(by: { $0.displayOrder < $1.displayOrder })
    }
    
    var currencies: [CurrencyDef] {
        return orderedWallets.map { $0.currency }
    }
    
    var primaryWallet: WalletState {
        return wallets[Currencies.btc.code]!
    }
}

extension State {
    static var initial: State {
        return State(   isStartFlowVisible: false,
                        isLoginRequired: true,
                        rootModal: .none,
                        isBtcSwapped: UserDefaults.isBtcSwapped,
                        alert: nil,
                        isBiometricsEnabled: UserDefaults.isBiometricsEnabled,
                        defaultCurrencyCode: UserDefaults.defaultCurrencyCode,
                        isPushNotificationsEnabled: UserDefaults.pushToken != nil,
                        isPromptingBiometrics: false,
                        pinLength: 6,
                        wallets: [Currencies.btc.code: WalletState.initial(Currencies.btc, displayOrder: 0),
                                  Currencies.bch.code: WalletState.initial(Currencies.bch, displayOrder: 1)])
    }
    
    func mutate(   isStartFlowVisible: Bool? = nil,
                   isLoginRequired: Bool? = nil,
                   rootModal: RootModal? = nil,
                   isBtcSwapped: Bool? = nil,
                   alert: AlertType? = nil,
                   isBiometricsEnabled: Bool? = nil,
                   defaultCurrencyCode: String? = nil,
                   isPushNotificationsEnabled: Bool? = nil,
                   isPromptingBiometrics: Bool? = nil,
                   pinLength: Int? = nil,
                   wallets: [String: WalletState]? = nil) -> State {
        return State(isStartFlowVisible: isStartFlowVisible ?? self.isStartFlowVisible,
                     isLoginRequired: isLoginRequired ?? self.isLoginRequired,
                     rootModal: rootModal ?? self.rootModal,
                     isBtcSwapped: isBtcSwapped ?? self.isBtcSwapped,
                     alert: alert ?? self.alert,
                     isBiometricsEnabled: isBiometricsEnabled ?? self.isBiometricsEnabled,
                     defaultCurrencyCode: defaultCurrencyCode ?? self.defaultCurrencyCode,
                     isPushNotificationsEnabled: isPushNotificationsEnabled ?? self.isPushNotificationsEnabled,
                     isPromptingBiometrics: isPromptingBiometrics ?? self.isPromptingBiometrics,
                     pinLength: pinLength ?? self.pinLength,
                     wallets: wallets ?? self.wallets)
    }
    
    func mutate(walletState: WalletState) -> State {
        var wallets = self.wallets
        wallets[walletState.currency.code] = walletState
        return mutate(wallets: wallets)
    }
}

// MARK: -

enum RootModal {
    case none
    case send(currency: CurrencyDef)
    case receive(currency: CurrencyDef)
    case loginAddress
    case loginScan
    case requestAmount(currency: CurrencyDef)
    case buy
}

enum SyncState {
    case syncing
    case connecting
    case success
}

// MARK: -

struct WalletState {
    let currency: CurrencyDef
    let displayOrder: Int
    let syncProgress: Double
    let syncState: SyncState
    let balance: UInt64?
    let transactions: [Transaction]
    let lastBlockTimestamp: UInt32
    let name: String
    let creationDate: Date
    let isRescanning: Bool
    let receiveAddress: String?
    let bigBalance: GethBigInt? // ??
    let token: ERC20Token? // ??
    let numSent: Int // ??
    let rates: [Rate]
    let currentRate: Rate?
    let fees: Fees?
    let recommendRescan: Bool
    let maxDigits: Int // this is bits vs bitcoin setting
    let connectionStatus: BRPeerStatus
//    let isBtcSwapped: Bool // show amounts as fiat setting
    
    
    static func initial(_ currency: CurrencyDef, displayOrder: Int) -> WalletState {
        return WalletState(currency: currency,
                           displayOrder: displayOrder,
                           syncProgress: 0.0,
                           syncState: .success,
                           balance: nil,
                           transactions: [],
                           lastBlockTimestamp: 0,
                           name: S.AccountHeader.defaultWalletName,
                           creationDate: Date.zeroValue(),
                           isRescanning: false,
                           receiveAddress: nil,
                           bigBalance: nil,
                           token: nil,
                           numSent: 0,
                           rates: [],
                           currentRate: UserDefaults.currentRate(forCode: currency.code),
                           fees: nil,
                           recommendRescan: false,
                           maxDigits: UserDefaults.maxDigits,
                           connectionStatus: BRPeerStatusDisconnected)
    }

    func mutate(    displayOrder: Int? = nil,
                    syncProgress: Double? = nil,
                    syncState: SyncState? = nil,
                    balance: UInt64? = nil,
                    transactions: [Transaction]? = nil,
                    lastBlockTimestamp: UInt32? = nil,
                    name: String? = nil,
                    creationDate: Date? = nil,
                    isRescanning: Bool? = nil,
                    receiveAddress: String? = nil,
                    bigBalance: GethBigInt? = nil,
                    token: ERC20Token? = nil,
                    numSent: Int? = nil,
                    currentRate: Rate? = nil,
                    rates: [Rate]? = nil,
                    fees: Fees? = nil,
                    recommendRescan: Bool? = nil,
                    maxDigits: Int? = nil,
                    connectionStatus: BRPeerStatus? = nil) -> WalletState {

        return WalletState(currency: self.currency,
                           displayOrder: displayOrder ?? self.displayOrder,
                           syncProgress: syncProgress ?? self.syncProgress,
                           syncState: syncState ?? self.syncState,
                           balance: balance ?? self.balance,
                           transactions: transactions ?? self.transactions,
                           lastBlockTimestamp: lastBlockTimestamp ?? self.lastBlockTimestamp,
                           name: name ?? self.name,
                           creationDate: creationDate ?? self.creationDate,
                           isRescanning: isRescanning ?? self.isRescanning,
                           receiveAddress: receiveAddress ?? self.receiveAddress,
                           bigBalance: bigBalance ?? self.bigBalance,
                           token: token ?? self.token,
                           numSent: numSent ?? self.numSent,
                           rates: rates ?? self.rates,
                           currentRate: currentRate ?? self.currentRate,
                           fees: fees ?? self.fees,
                           recommendRescan: recommendRescan ?? self.recommendRescan,
                           maxDigits: maxDigits ?? self.maxDigits,
                           connectionStatus: connectionStatus ?? self.connectionStatus)
    }
}

extension WalletState : Equatable {}

func ==(lhs: WalletState, rhs: WalletState) -> Bool {
    return lhs.currency.code == rhs.currency.code &&
        lhs.syncProgress == rhs.syncProgress &&
        lhs.syncState == rhs.syncState &&
        lhs.balance == rhs.balance &&
        lhs.transactions == rhs.transactions &&
        lhs.name == rhs.name &&
        lhs.creationDate == rhs.creationDate &&
        lhs.isRescanning == rhs.isRescanning &&
        lhs.numSent == rhs.numSent &&
        lhs.rates == rhs.rates &&
        lhs.currentRate == rhs.currentRate &&
        lhs.fees == rhs.fees &&
        lhs.recommendRescan == rhs.recommendRescan &&
        lhs.maxDigits == rhs.maxDigits &&
        lhs.connectionStatus == rhs.connectionStatus
}

extension RootModal : Equatable {}

func ==(lhs: RootModal, rhs: RootModal) -> Bool {
    switch(lhs, rhs) {
    case (.none, .none):
        return true
    case (.send(let lhsCurrency), .send(let rhsCurrency)):
        return lhsCurrency.code == rhsCurrency.code
    case (.receive(let lhsCurrency), .receive(let rhsCurrency)):
        return lhsCurrency.code == rhsCurrency.code
    case (.loginAddress, .loginAddress):
        return true
    case (.loginScan, .loginScan):
        return true
    case (.requestAmount(let lhsCurrency), .requestAmount(let rhsCurrency)):
        return lhsCurrency.code == rhsCurrency.code
    case (.buy, .buy):
        return true
    default:
        return false
    }
}


extension CurrencyDef {
    var state: WalletState {
        return Store.state[self]
    }
}
