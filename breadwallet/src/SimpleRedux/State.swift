//
//  State.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-10-24.
//  Copyright © 2016-2019 Breadwinner AG. All rights reserved.
//

import UIKit
import BRCore

struct State {
    let isLoginRequired: Bool
    let rootModal: RootModal
    let showFiatAmounts: Bool
    let alert: AlertType
    let isBiometricsEnabled: Bool
    let defaultCurrencyCode: String
    let isPushNotificationsEnabled: Bool
    let isPromptingBiometrics: Bool
    let pinLength: Int
    let accountName: String
    let creationDate: Date
    let walletID: String?
    let wallets: [String: WalletState]
    let availableTokens: [Currency]
    
    subscript(currency: Currency) -> WalletState? {
        guard let walletState = wallets[currency.code] else {
            return nil
        }
        return walletState
    }
    
    var orderedWallets: [WalletState] {
        //TODO:CRYPTO wallet management
        return wallets.values.sorted(by: { $0.currency.code < $1.currency.code })//wallets.values.sorted(by: { $0.displayOrder < $1.displayOrder })
    }
    
    var currencies: [Currency] {
        return orderedWallets.map { $0.currency }
    }

    var displayCurrencies: [Currency] {
        return orderedWallets.filter { $0.displayOrder >= 0 }.map { $0.currency }
    }
    
    var supportedTokens: [Currency] {
        return availableTokens.filter { $0.isSupported }
    }
    
    var shouldShowBuyNotificationForDefaultCurrency: Bool {
        switch defaultCurrencyCode {
        // Currencies eligible for Coinify.
        case C.euroCurrencyCode,
             C.britishPoundCurrencyCode,
             C.danishKroneCurrencyCode:
            return true
        default:
            return false
        }
    }
}

extension State {
    static var initial: State {
        return State(   isLoginRequired: true,
                        rootModal: .none,
                        showFiatAmounts: UserDefaults.showFiatAmounts,
                        alert: .none,
                        isBiometricsEnabled: UserDefaults.isBiometricsEnabled,
                        defaultCurrencyCode: UserDefaults.defaultCurrencyCode,
                        isPushNotificationsEnabled: UserDefaults.pushToken != nil,
                        isPromptingBiometrics: false,
                        pinLength: 6,
                        accountName: S.AccountHeader.defaultWalletName,
                        creationDate: Date.zeroValue(),
                        walletID: nil,
                        //TODO:CRYPTO default wallets
                        wallets: [:],
//                        wallets: [Currencies.btc.code: WalletState.initial(Currencies.btc, displayOrder: -1),
//                                  Currencies.bch.code: WalletState.initial(Currencies.bch, displayOrder: -1),
//                                  Currencies.eth.code: WalletState.initial(Currencies.eth, displayOrder: -1),
//                                  Currencies.brd.code: WalletState.initial(Currencies.brd, displayOrder: -1)],
                        //availableTokens: [Currencies.brd]
                        availableTokens: []
        )
    }
    
    func mutate(   isOnboardingEnabled: Bool? = nil,
                   isLoginRequired: Bool? = nil,
                   rootModal: RootModal? = nil,
                   showFiatAmounts: Bool? = nil,
                   alert: AlertType? = nil,
                   isBiometricsEnabled: Bool? = nil,
                   defaultCurrencyCode: String? = nil,
                   isPushNotificationsEnabled: Bool? = nil,
                   isPromptingBiometrics: Bool? = nil,
                   pinLength: Int? = nil,
                   accountName: String? = nil,
                   creationDate: Date? = nil,
                   walletID: String? = nil,
                   wallets: [String: WalletState]? = nil,
                   availableTokens: [Currency]? = nil) -> State {
        return State(isLoginRequired: isLoginRequired ?? self.isLoginRequired,
                     rootModal: rootModal ?? self.rootModal,
                     showFiatAmounts: showFiatAmounts ?? self.showFiatAmounts,
                     alert: alert ?? self.alert,
                     isBiometricsEnabled: isBiometricsEnabled ?? self.isBiometricsEnabled,
                     defaultCurrencyCode: defaultCurrencyCode ?? self.defaultCurrencyCode,
                     isPushNotificationsEnabled: isPushNotificationsEnabled ?? self.isPushNotificationsEnabled,
                     isPromptingBiometrics: isPromptingBiometrics ?? self.isPromptingBiometrics,
                     pinLength: pinLength ?? self.pinLength,
                     accountName: accountName ?? self.accountName,
                     creationDate: creationDate ?? self.creationDate,
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
    case send(currency: Currency)
    case sendForRequest(request: PigeonRequest)
    case receive(currency: Currency)
    case loginScan
    case requestAmount(currency: Currency, address: String)
    case buy(currency: Currency?)
    case sell(currency: Currency?)
    case trade
    case receiveLegacy
}

enum SyncState {
    case syncing
    case connecting
    case success
}

// MARK: -

struct WalletState {
    let currency: Currency
    let wallet: Wallet?
    let displayOrder: Int // -1 for hidden
    let syncProgress: Double
    let syncState: SyncState
    let balance: Amount?
    let lastBlockTimestamp: UInt32
    var receiveAddress: String? {
        return wallet?.receiveAddress
    }
    let legacyReceiveAddress: String?
    let rates: [Rate]
    let currentRate: Rate?
    let fees: Fees?
    let connectionStatus: BRPeerStatus
    let priceChange: PriceChange?

    static func initial(_ currency: Currency, wallet: Wallet? = nil, displayOrder: Int) -> WalletState {
        return WalletState(currency: currency,
                           wallet: wallet,
                           displayOrder: displayOrder,
                           syncProgress: 0.0,
                           syncState: .success,
                           balance: nil,
                           lastBlockTimestamp: 0,
                           legacyReceiveAddress: nil,
                           rates: [],
                           currentRate: UserDefaults.currentRate(forCode: currency.code),
                           fees: nil,
                           connectionStatus: BRPeerStatusDisconnected,
                           priceChange: nil)
    }

    func mutate(    displayOrder: Int? = nil,
                    syncProgress: Double? = nil,
                    syncState: SyncState? = nil,
                    balance: Amount? = nil,
                    lastBlockTimestamp: UInt32? = nil,
                    receiveAddress: String? = nil,
                    legacyReceiveAddress: String? = nil,
                    currentRate: Rate? = nil,
                    rates: [Rate]? = nil,
                    fees: Fees? = nil,
                    connectionStatus: BRPeerStatus? = nil,
                    priceChange: PriceChange? = nil) -> WalletState {

        return WalletState(currency: self.currency,
                           wallet: self.wallet,
                           displayOrder: displayOrder ?? self.displayOrder,
                           syncProgress: syncProgress ?? self.syncProgress,
                           syncState: syncState ?? self.syncState,
                           balance: balance ?? self.balance,
                           lastBlockTimestamp: lastBlockTimestamp ?? self.lastBlockTimestamp,
                           legacyReceiveAddress: legacyReceiveAddress ?? self.legacyReceiveAddress,
                           rates: rates ?? self.rates,
                           currentRate: currentRate ?? self.currentRate,
                           fees: fees ?? self.fees,
                           connectionStatus: connectionStatus ?? self.connectionStatus,
                           priceChange: priceChange ?? self.priceChange)
    }
}

extension WalletState: Equatable {}

func == (lhs: WalletState, rhs: WalletState) -> Bool {
    return lhs.currency.code == rhs.currency.code &&
        lhs.syncProgress == rhs.syncProgress &&
        lhs.syncState == rhs.syncState &&
        lhs.balance == rhs.balance &&
        lhs.rates == rhs.rates &&
        lhs.currentRate == rhs.currentRate &&
        lhs.fees == rhs.fees &&
        lhs.connectionStatus == rhs.connectionStatus &&
        lhs.legacyReceiveAddress == rhs.legacyReceiveAddress
}

extension RootModal: Equatable {}

func == (lhs: RootModal, rhs: RootModal) -> Bool {
    switch(lhs, rhs) {
    case (.none, .none):
        return true
    case (.send(let lhsCurrency), .send(let rhsCurrency)):
        return lhsCurrency.code == rhsCurrency.code
    case (.sendForRequest(let lhsRequest), .sendForRequest(let rhsRequest)):
        return lhsRequest.address == rhsRequest.address
    case (.receive(let lhsCurrency), .receive(let rhsCurrency)):
        return lhsCurrency.code == rhsCurrency.code
    case (.loginScan, .loginScan):
        return true
    case (.requestAmount(let lhsCurrency, let lhsAddress), .requestAmount(let rhsCurrency, let rhsAddress)):
        return lhsCurrency.code == rhsCurrency.code && lhsAddress == rhsAddress
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
    case (.receiveLegacy, .receiveLegacy):
        return true
    default:
        return false
    }
}

extension Currency {
    var state: WalletState? {
        return Store.state[self]
    }
}
