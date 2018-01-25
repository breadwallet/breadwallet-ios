//
//  State.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-24.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit

struct State {
    let isStartFlowVisible: Bool
    let isLoginRequired: Bool
    let rootModal: RootModal
    //--vvvv
    let walletState: WalletState // need one per currency?
    let isBtcSwapped: Bool //move to CurrencyState
//    let currentRate: Rate? //move to CurrencyState
    let rates: [Rate] //move to CurrencyState
    //--^^^^
    let alert: AlertType?
    let isBiometricsEnabled: Bool
    let defaultCurrencyCode: String
    //--vvvv
    let recommendRescan: Bool // wallet-specific
    let isLoadingTransactions: Bool // wallet-specific
    let maxDigits: Int //move to CurrencyState - (this is bits vs bitcoin setting)
    //--^^^^
    let isPushNotificationsEnabled: Bool
    let isPromptingBiometrics: Bool
    let pinLength: Int
    //--vvvv
    let fees: Fees? //move to CurrencyState
    let colours: (UIColor, UIColor) //moved to CurrencyDef
    let currencies: [CurrencyDef]
    //--^^^^
    let wallets: [String: Wallet]
    
    subscript(currency: CurrencyDef) -> Wallet? {
        return wallets[currency.code]
    }
    
    var primaryWallet: Wallet {
        return wallets[Currencies.btc.code]!
    }
}

extension State {
    static var initial: State {
        return State(   isStartFlowVisible: false,
                        isLoginRequired: true,
                        rootModal: .none,
                        walletState: WalletState.initial,
                        isBtcSwapped: UserDefaults.isBtcSwapped,
                        //                        currentRate: nil,
            rates: [],
            alert: nil,
            isBiometricsEnabled: UserDefaults.isBiometricsEnabled,
            defaultCurrencyCode: UserDefaults.defaultCurrencyCode,
            recommendRescan: false,
            isLoadingTransactions: false,
            maxDigits: UserDefaults.maxDigits,
            isPushNotificationsEnabled: UserDefaults.pushToken != nil,
            isPromptingBiometrics: false,
            pinLength: 6,
            fees: nil,
            colours: (UIColor(), UIColor()),
            currencies: [Currencies.btc, Currencies.bch],
            wallets: [Currencies.btc.code: Wallet.initial(Currencies.btc),
                      Currencies.bch.code: Wallet.initial(Currencies.bch)])
    }
    
    func mutate(   isStartFlowVisible: Bool? = nil,
                   isLoginRequired: Bool? = nil,
                   rootModal: RootModal? = nil,
                   walletState: WalletState? = nil,
                   isBtcSwapped: Bool? = nil,
                   currentRate: Rate? = nil,
                   rates: [Rate]? = nil,
                   alert: AlertType? = nil,
                   isBiometricsEnabled: Bool? = nil,
                   defaultCurrencyCode: String? = nil,
                   recommendRescan: Bool? = nil,
                   isLoadingTransactions: Bool? = nil,
                   maxDigits: Int? = nil,
                   isPushNotificationsEnabled: Bool? = nil,
                   isPromptingBiometrics: Bool? = nil,
                   pinLength: Int? = nil,
                   fees: Fees? = nil,
                   colours: (UIColor, UIColor)? = nil,
                   currencies: [CurrencyDef]? = nil,
                   wallets: [String: Wallet]? = nil) -> State {
        return State(isStartFlowVisible: isStartFlowVisible ?? self.isStartFlowVisible,
                     isLoginRequired: isLoginRequired ?? self.isLoginRequired,
                     rootModal: rootModal ?? self.rootModal,
                     walletState: walletState ?? self.walletState,
                     isBtcSwapped: isBtcSwapped ?? self.isBtcSwapped,
//                     currentRate: currentRate ?? self.currentRate,
                     rates: rates ?? self.rates,
                     alert: alert ?? self.alert,
                     isBiometricsEnabled: isBiometricsEnabled ?? self.isBiometricsEnabled,
                     defaultCurrencyCode: defaultCurrencyCode ?? self.defaultCurrencyCode,
                     recommendRescan: recommendRescan ?? self.recommendRescan,
                     isLoadingTransactions: isLoadingTransactions ?? self.isLoadingTransactions,
                     maxDigits: maxDigits ?? self.maxDigits,
                     isPushNotificationsEnabled: isPushNotificationsEnabled ?? self.isPushNotificationsEnabled,
                     isPromptingBiometrics: isPromptingBiometrics ?? self.isPromptingBiometrics,
                     pinLength: pinLength ?? self.pinLength,
                     fees: fees ?? self.fees,
                     colours: colours ?? self.colours,
                     currencies: currencies ?? self.currencies,
                     wallets: wallets ?? self.wallets)
    }
}

// MARK: -

enum RootModal {
    case none
    case send
    case receive
    case menu
    case loginAddress
    case loginScan
    case requestAmount
    case buy
}

enum SyncState {
    case syncing
    case connecting
    case success
}

// MARK: -

struct WalletState {
    let isConnected: Bool
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
    let token: Token? // ??
    let numSent: Int // ??
    static var initial: WalletState {
        return WalletState(isConnected: false, syncProgress: 0.0, syncState: .success, balance: nil, transactions: [], lastBlockTimestamp: 0, name: S.AccountHeader.defaultWalletName, creationDate: Date.zeroValue(), isRescanning: false, receiveAddress: nil, bigBalance: nil, token: nil, numSent: 0)
    }

    func mutate(    isConnected: Bool? = nil,
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
                    token: Token? = nil,
                    numSent: Int? = nil) -> WalletState {

        return WalletState(isConnected: isConnected ?? self.isConnected,
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
                           numSent: numSent ?? self.numSent)
    }
}

extension WalletState : Equatable {}

func ==(lhs: WalletState, rhs: WalletState) -> Bool {
    return lhs.isConnected == rhs.isConnected && lhs.syncProgress == rhs.syncProgress && lhs.syncState == rhs.syncState && lhs.balance == rhs.balance && lhs.transactions == rhs.transactions && lhs.name == rhs.name && lhs.creationDate == rhs.creationDate && lhs.isRescanning == rhs.isRescanning && lhs.numSent == rhs.numSent
}


// MARK: -

struct Wallet {
    let currency: CurrencyDef
    let walletState: WalletState
    let rates: [Rate]
    let currentRate: Rate?
    let fees: Fees?
    let recommendRescan: Bool
    let isLoadingTransactions: Bool
    let maxDigits: Int // this is bits vs bitcoin setting
    let isBtcSwapped: Bool // show amounts as fiat setting
}

extension Wallet {
    static func initial(_ currency: CurrencyDef) -> Wallet {
        return Wallet(currency: currency,
                      walletState: WalletState.initial,
                      rates: [],
                      currentRate: nil,
                      fees: nil,
                      recommendRescan: false,
                      isLoadingTransactions: false,
                      maxDigits: UserDefaults.maxDigits,
                      isBtcSwapped: false)
    }
    
    func mutate(   walletState: WalletState? = nil,
                   currentRate: Rate? = nil,
                   rates: [Rate]? = nil,
                   fees: Fees? = nil,
                   recommendRescan: Bool? = nil,
                   isLoadingTransactions: Bool? = nil,
                   maxDigits: Int? = nil,
                   isBtcSwapped: Bool? = nil) -> Wallet {
        return Wallet(currency: self.currency,
                      walletState: walletState ?? self.walletState,
                      rates: rates ?? self.rates,
                      currentRate: currentRate ?? self.currentRate,
                      fees: fees ?? self.fees,
                      recommendRescan: recommendRescan ?? self.recommendRescan,
                      isLoadingTransactions: isLoadingTransactions ?? self.isLoadingTransactions,
                      maxDigits: maxDigits ?? self.maxDigits,
                      isBtcSwapped: isBtcSwapped ?? self.isBtcSwapped)
    }
}

extension Wallet : Equatable {}

func ==(lhs: Wallet, rhs: Wallet) -> Bool {
    return lhs.currency.code == rhs.currency.code && lhs.walletState == rhs.walletState && lhs.rates == rhs.rates && lhs.currentRate == rhs.currentRate && lhs.fees == rhs.fees && lhs.recommendRescan == rhs.recommendRescan && lhs.isLoadingTransactions == rhs.isLoadingTransactions && lhs.maxDigits == rhs.maxDigits && lhs.isBtcSwapped == rhs.isBtcSwapped
}
