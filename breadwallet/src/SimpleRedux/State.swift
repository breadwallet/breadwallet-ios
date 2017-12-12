//
//  State.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-24.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit
import Geth

struct State {
    let isStartFlowVisible: Bool
    let isLoginRequired: Bool
    let rootModal: RootModal
    let walletState: WalletState
    let isBtcSwapped: Bool
    let currentRate: Rate?
    let rates: [Rate]
    let alert: AlertType?
    let isBiometricsEnabled: Bool
    let defaultCurrencyCode: String
    let recommendRescan: Bool
    let isLoadingTransactions: Bool
    let maxDigits: Int
    let isPushNotificationsEnabled: Bool
    let isPromptingBiometrics: Bool
    let pinLength: Int
    let fees: Fees
    let currency: Currency
    let colours: (UIColor, UIColor)
}

extension State {
    static var initial: State {
        return State(   isStartFlowVisible: false,
                        isLoginRequired: true,
                        rootModal: .none,
                        walletState: WalletState.initial,
                        isBtcSwapped: UserDefaults.isBtcSwapped,
                        currentRate: nil,
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
                        fees: Fees.defaultFees,
                        currency: .bitcoin,
                        colours: (UIColor(), UIColor()))
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
                   currency: Currency? = nil,
                   colours: (UIColor, UIColor)? = nil) -> State {
        return State(isStartFlowVisible: isStartFlowVisible ?? self.isStartFlowVisible, isLoginRequired: isLoginRequired ?? self.isLoginRequired, rootModal: rootModal ?? self.rootModal, walletState: walletState ?? self.walletState, isBtcSwapped: isBtcSwapped ?? self.isBtcSwapped, currentRate: currentRate ?? self.currentRate, rates: rates ?? self.rates, alert: alert ?? self.alert, isBiometricsEnabled: isBiometricsEnabled ?? self.isBiometricsEnabled, defaultCurrencyCode: defaultCurrencyCode ?? self.defaultCurrencyCode, recommendRescan: recommendRescan ?? self.recommendRescan, isLoadingTransactions: isLoadingTransactions ?? self.isLoadingTransactions, maxDigits: maxDigits ?? self.maxDigits, isPushNotificationsEnabled: isPushNotificationsEnabled ?? self.isPushNotificationsEnabled, isPromptingBiometrics: isPromptingBiometrics ?? self.isPromptingBiometrics, pinLength: pinLength ?? self.pinLength, fees: fees ?? self.fees, currency: currency ?? self.currency, colours: colours ?? self.colours)
    }
}

enum Currency {
    case bitcoin
    case ethereum
    case token

    func isValidAddress(_ string: String) -> Bool {
        switch self {
        case .bitcoin:
            return string.isValidAddress
        case .ethereum:
            return string.isValidEthAddress
        case .token:
            return string.isValidEthAddress
        }
    }

    var baseUnit: Double {
        switch self {
        case .bitcoin:
            return 100000000.0
        case .ethereum:
            return 1000000000000000000.0
        case .token:
            return 1000000000000000000.0
        }
    }

    var symbol: String {
        switch self {
        case .bitcoin:
            return "btc"
        case .ethereum:
            return "eth"
        case .token:
            return "xjp"
        }
    }
}

enum RootModal {
    case none
    case send
    case receive
    case menu
    case loginAddress
    case loginScan
    case manageWallet
    case requestAmount
    case countryPicker
}

enum SyncState {
    case syncing
    case connecting
    case success
}

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
    let bigBalance: GethBigInt?
    let token: Token?
    let numSent: Int
    let crowdsale: Crowdsale?
    static var initial: WalletState {
        return WalletState(isConnected: false, syncProgress: 0.0, syncState: .success, balance: nil, transactions: [], lastBlockTimestamp: 0, name: S.AccountHeader.defaultWalletName, creationDate: Date.zeroValue(), isRescanning: false, receiveAddress: nil, bigBalance: nil, token: nil, numSent: 0, crowdsale: nil)
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
                    numSent: Int? = nil,
                    crowdSale: Crowdsale? = nil) -> WalletState {

        return WalletState(isConnected: isConnected ?? self.isConnected, syncProgress: syncProgress ?? self.syncProgress, syncState: syncState ?? self.syncState, balance: balance ?? self.balance, transactions: transactions ?? self.transactions, lastBlockTimestamp: lastBlockTimestamp ?? self.lastBlockTimestamp, name: name ?? self.name, creationDate: creationDate ?? self.creationDate, isRescanning: isRescanning ?? self.isRescanning, receiveAddress: receiveAddress ?? self.receiveAddress, bigBalance: bigBalance ?? self.bigBalance, token: token ?? self.token, numSent: numSent ?? self.numSent, crowdsale: crowdSale ?? self.crowdsale)
    }
}

extension WalletState : Equatable {}

func ==(lhs: WalletState, rhs: WalletState) -> Bool {
    return lhs.isConnected == rhs.isConnected && lhs.syncProgress == rhs.syncProgress && lhs.syncState == rhs.syncState && lhs.balance == rhs.balance && lhs.transactions == rhs.transactions && lhs.name == rhs.name && lhs.creationDate == rhs.creationDate && lhs.isRescanning == rhs.isRescanning && lhs.numSent == rhs.numSent
}
