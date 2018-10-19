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
    let alert: AlertType
    let isBiometricsEnabled: Bool
    let defaultCurrencyCode: String
    let isPushNotificationsEnabled: Bool
    let isPromptingBiometrics: Bool
    let pinLength: Int
    let walletID: String?
    let wallets: [String: WalletState]
    let availableTokens: [ERC20Token]
    
    subscript(currency: CurrencyDef) -> WalletState? {
        guard let walletState = wallets[currency.code] else {
            return nil
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

    var displayCurrencies: [CurrencyDef] {
        return orderedWallets.filter { $0.displayOrder >= 0 }.map { $0.currency }
    }
    
    var supportedTokens: [ERC20Token] {
        return availableTokens.filter { $0.isSupported }
    }
}

extension State {
    static var initial: State {
        return State(   isStartFlowVisible: false,
                        isLoginRequired: true,
                        rootModal: .none,
                        isBtcSwapped: UserDefaults.isBtcSwapped,
                        alert: .none,
                        isBiometricsEnabled: UserDefaults.isBiometricsEnabled,
                        defaultCurrencyCode: UserDefaults.defaultCurrencyCode,
                        isPushNotificationsEnabled: UserDefaults.pushToken != nil,
                        isPromptingBiometrics: false,
                        pinLength: 6,
                        walletID: nil,
                        wallets: [Currencies.btc.code: WalletState.initial(Currencies.btc, displayOrder: -1),
                                  Currencies.bch.code: WalletState.initial(Currencies.bch, displayOrder: -1),
                                  Currencies.eth.code: WalletState.initial(Currencies.eth, displayOrder: -1),
                                  Currencies.brd.code: WalletState.initial(Currencies.brd, displayOrder: -1)],
                        availableTokens: [Currencies.brd]
        )
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
                   walletID: String? = nil,
                   wallets: [String: WalletState]? = nil,
                   availableTokens: [ERC20Token]? = nil) -> State {
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
                     walletID: walletID ?? self.walletID,
                     wallets: wallets ?? self.wallets,
                     availableTokens: availableTokens ?? self.availableTokens)
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
    case sendForRequest(request: PigeonRequest)
    case receive(currency: CurrencyDef)
    case loginAddress
    case loginScan
    case requestAmount(currency: CurrencyDef)
    case buy(currency: CurrencyDef?)
    case sell(currency: CurrencyDef?)
    case trade
}

enum SyncState {
    case syncing
    case connecting
    case success
}

// MARK: -

struct WalletState {
    let currency: CurrencyDef
    let displayOrder: Int // -1 for hidden
    let syncProgress: Double
    let syncState: SyncState
    let balance: UInt256?
    let transactions: [Transaction]
    let lastBlockTimestamp: UInt32
    let name: String
    let creationDate: Date
    let isRescanning: Bool
    let receiveAddress: String?
    let rates: [Rate]
    let currentRate: Rate?
    let fees: Fees?
    let maxDigits: Int // this is bits vs bitcoin setting
    let connectionStatus: BRPeerStatus
    
    
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
                           rates: [],
                           currentRate: UserDefaults.currentRate(forCode: currency.code),
                           fees: nil,
                           maxDigits: (currency is Bitcoin) ? UserDefaults.maxDigits : currency.commonUnit.decimals,
                           connectionStatus: BRPeerStatusDisconnected)
    }

    func mutate(    displayOrder: Int? = nil,
                    syncProgress: Double? = nil,
                    syncState: SyncState? = nil,
                    balance: UInt256? = nil,
                    transactions: [Transaction]? = nil,
                    lastBlockTimestamp: UInt32? = nil,
                    name: String? = nil,
                    creationDate: Date? = nil,
                    isRescanning: Bool? = nil,
                    receiveAddress: String? = nil,
                    currentRate: Rate? = nil,
                    rates: [Rate]? = nil,
                    fees: Fees? = nil,
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
                           rates: rates ?? self.rates,
                           currentRate: currentRate ?? self.currentRate,
                           fees: fees ?? self.fees,
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
        lhs.rates == rhs.rates &&
        lhs.currentRate == rhs.currentRate &&
        lhs.fees == rhs.fees &&
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
    case (.sendForRequest(let lhsRequest), .sendForRequest(let rhsRequest)):
        return lhsRequest.address == rhsRequest.address
    case (.receive(let lhsCurrency), .receive(let rhsCurrency)):
        return lhsCurrency.code == rhsCurrency.code
    case (.loginAddress, .loginAddress):
        return true
    case (.loginScan, .loginScan):
        return true
    case (.requestAmount(let lhsCurrency), .requestAmount(let rhsCurrency)):
        return lhsCurrency.code == rhsCurrency.code
    case (.buy(let lhsCurrency?), .buy(let rhsCurrency?)):
        return lhsCurrency.code == rhsCurrency.code
    case (.buy(nil), .buy(nil)):
        return true
    case (.sell(let lhsCurrency?), .sell(let rhsCurrency?)):
        return lhsCurrency.code == rhsCurrency.code
    case (.sell(nil), .sell(nil)):
        return true
    case (.trade, .trade):
        return true
    default:
        return false
    }
}


extension CurrencyDef {
    var state: WalletState? {
        return Store.state[self]
    }
}
