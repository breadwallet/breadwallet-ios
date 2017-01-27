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
        return $0.clone(isStartFlowVisible: true)
    }
}

struct HideStartFlow : Action {
    let reduce: Reducer = { state in
        return State(isStartFlowVisible: false,
                     isLoginRequired: state.isLoginRequired,
                     pinCreationStep: .none,
                     paperPhraseStep: .none,
                     rootModal: .none,
                     pasteboard: UIPasteboard.general.string,
                     isModalDismissalBlocked: false,
                     walletState: state.walletState,
                     currency: state.currency,
                     currentRate: state.currentRate)
    }
}

struct RequireLogin : Action {
    let reduce: Reducer = {
        return $0.clone(isLoginRequired: true)
    }
}

struct LoginSuccess : Action {
    let reduce: Reducer = {
        return $0.clone(isLoginRequired: false)
    }
}

//MARK: - Pin Creation
struct PinCreation {

    struct PinEntryComplete : Action {
        let reduce: Reducer

        init(newPin: String) {
            reduce = {
                switch $0.pinCreationStep {
                case .start:
                    return $0.clone(pinCreationStep: .confirm(pin: newPin))
                case .confirm(let previousPin):
                    return stateForNewPin(newPin: newPin, previousPin: previousPin, state: $0)
                case .confirmFail(let previousPin):
                    return stateForNewPin(newPin: newPin, previousPin: previousPin, state: $0)
                default:
                    assert(false, "Warning - invalid state")
                }
            }
        }
    }

    struct Reset : Action {
        let reduce: Reducer = {
            return $0.clone(pinCreationStep: .none)
        }
    }

    struct Start : Action {
        let reduce: Reducer = {
            return $0.clone(pinCreationStep: .start)
        }
    }

    struct SaveSuccess : Action {
        let reduce: Reducer = {
            switch $0.pinCreationStep {
            case .save(let pin):
                return $0.clone(pinCreationStep: .saveSuccess(pin: pin))
            default:
                assert(false, "Warning - invalid state")
            }
        }
    }
}

fileprivate func stateForNewPin(newPin: String, previousPin: String, state: State) -> State {
    if newPin == previousPin {
        return state.clone(pinCreationStep: .save(pin: newPin))
    } else {
        return state.clone(pinCreationStep: .confirmFail(pin: previousPin))
    }
}

//MARK: - Paper Phrase
struct PaperPhrase {
    struct Start: Action {
        let reduce: Reducer = {
            return $0.clone(paperPhraseStep: .start)
        }
    }

    struct Write: Action {
        let reduce: Reducer = {
            return $0.clone(paperPhraseStep: .write)
        }
    }

    struct Confirm: Action {
        let reduce: Reducer = {
            return $0.clone(paperPhraseStep: .confirm)
        }
    }

    struct Confirmed: Action {
        let reduce: Reducer = {
            return $0.clone(paperPhraseStep: .confirmed)
        }
    }
} 

//MARK: - Root Modals
struct RootModalActions {
    struct Send: Action {
        let reduce: Reducer = { $0.rootModal(.send) }
    }

    struct Receive: Action {
        let reduce: Reducer = { $0.rootModal(.receive) }
    }

    struct Menu: Action {
        let reduce: Reducer = { $0.rootModal(.menu) }
    }

    struct Reset: Action {
        let reduce: Reducer = { $0.rootModal(.none) }
    }
}

//MARK: - Pasteboard
struct Pasteboard {
    struct refresh: Action {
        let reduce: Reducer = { $0.clone(pasteboard: UIPasteboard.general.string) }
    }
}

//MARK: - Modal Dismissal Blocking
enum ModalDismissal {
    struct block: Action {
        let reduce: Reducer = { $0.clone(isModalDismissalBlocked: true) }
    }

    struct unBlock: Action {
        let reduce: Reducer = { $0.clone(isModalDismissalBlocked: false) }
    }
}

//MARK: - Wallet State
enum WalletChange {
    struct setProgress: Action {
        let reduce: Reducer
        init(progress: Double) {
            reduce = { $0.clone(walletSyncProgress: progress) }
        }
    }
    struct setIsSyncing: Action {
        let reduce: Reducer
        init(_ isSyncing: Bool) {
            reduce = { $0.clone(walletIsSyncing: isSyncing) }
        }
    }
    struct setBalance: Action {
        let reduce: Reducer
        init(_ balance: UInt64) {
            reduce = { $0.clone(balance: balance) }
        }
    }
    struct setTransactions: Action {
        let reduce: Reducer
        init(_ transactions: [Transaction]) {
            reduce = { $0.clone(transactions: transactions) }
        }
    }
}

//MARK: - Currency
enum CurrencyChange {
    struct toggle: Action {
        let reduce: Reducer = {
            if $0.currency == .bitcoin {
                return $0.clone(currency: .local)
            } else {
                return $0.clone(currency: .bitcoin)
            }
        }
    }
}

//MARK: - Exchange Rates
enum ExchangeRates {
    struct setRate : Action {
        let reduce: Reducer
        init( _ rate: Rate) {
            reduce = { $0.clone(currentRate: rate) }
        }
    }
}

//MARK: - State Creation Helpers
extension State {
    func clone(isStartFlowVisible: Bool) -> State {
        return State(isStartFlowVisible: isStartFlowVisible,
                     isLoginRequired: isLoginRequired,
                     pinCreationStep: self.pinCreationStep,
                     paperPhraseStep: self.paperPhraseStep,
                     rootModal: self.rootModal,
                     pasteboard: self.pasteboard,
                     isModalDismissalBlocked: self.isModalDismissalBlocked,
                     walletState: self.walletState,
                     currency: currency,
                     currentRate: currentRate)
    }
    func clone(pinCreationStep: PinCreationStep) -> State {
        return State(isStartFlowVisible: self.isStartFlowVisible,
                     isLoginRequired: isLoginRequired,
                     pinCreationStep: pinCreationStep,
                     paperPhraseStep: self.paperPhraseStep,
                     rootModal: self.rootModal,
                     pasteboard: self.pasteboard,
                     isModalDismissalBlocked: self.isModalDismissalBlocked,
                     walletState: self.walletState,
                     currency: currency,
                     currentRate: currentRate)
    }

    func rootModal(_ type: RootModal) -> State {
        return State(isStartFlowVisible: false,
                     isLoginRequired: isLoginRequired,
                     pinCreationStep: .none,
                     paperPhraseStep: .none,
                     rootModal: type,
                     pasteboard: self.pasteboard,
                     isModalDismissalBlocked: self.isModalDismissalBlocked,
                     walletState: self.walletState,
                     currency: currency,
                     currentRate: currentRate)
    }
    func clone(pasteboard: String?) -> State {
        return State(isStartFlowVisible: self.isStartFlowVisible,
                     isLoginRequired: isLoginRequired,
                     pinCreationStep: pinCreationStep,
                     paperPhraseStep: self.paperPhraseStep,
                     rootModal: self.rootModal,
                     pasteboard: pasteboard,
                     isModalDismissalBlocked: self.isModalDismissalBlocked,
                     walletState: self.walletState,
                     currency: currency,
                     currentRate: currentRate)
    }
    func clone(isModalDismissalBlocked: Bool) -> State {
        return State(isStartFlowVisible: self.isStartFlowVisible,
                     isLoginRequired: isLoginRequired,
                     pinCreationStep: pinCreationStep,
                     paperPhraseStep: self.paperPhraseStep,
                     rootModal: self.rootModal,
                     pasteboard: self.pasteboard,
                     isModalDismissalBlocked: isModalDismissalBlocked,
                     walletState: self.walletState,
                     currency: currency,
                     currentRate: currentRate)
    }
    func clone(paperPhraseStep: PaperPhraseStep) -> State {
        return State(isStartFlowVisible: self.isStartFlowVisible,
                     isLoginRequired: isLoginRequired,
                     pinCreationStep: self.pinCreationStep,
                     paperPhraseStep: paperPhraseStep,
                     rootModal: self.rootModal,
                     pasteboard: self.pasteboard,
                     isModalDismissalBlocked: self.isModalDismissalBlocked,
                     walletState: self.walletState,
                     currency: currency,
                     currentRate: currentRate)
    }
    func clone(walletSyncProgress: Double) -> State {
        return State(isStartFlowVisible: self.isStartFlowVisible,
                     isLoginRequired: isLoginRequired,
                     pinCreationStep: self.pinCreationStep,
                     paperPhraseStep: self.paperPhraseStep,
                     rootModal: self.rootModal,
                     pasteboard: self.pasteboard,
                     isModalDismissalBlocked: self.isModalDismissalBlocked,
                     walletState: WalletState(isConnected: self.walletState.isConnected, syncProgress: walletSyncProgress, isSyncing: self.walletState.isSyncing, balance: walletState.balance, transactions: walletState.transactions),
                     currency: currency,
                     currentRate: currentRate)
    }
    func clone(walletIsSyncing: Bool) -> State {
        return State(isStartFlowVisible: isStartFlowVisible,
                     isLoginRequired: isLoginRequired,
                     pinCreationStep: pinCreationStep,
                     paperPhraseStep: paperPhraseStep,
                     rootModal: rootModal,
                     pasteboard: pasteboard,
                     isModalDismissalBlocked: isModalDismissalBlocked,
                     walletState: WalletState(isConnected: walletState.isConnected, syncProgress: walletState.syncProgress, isSyncing: walletIsSyncing, balance: walletState.balance, transactions: walletState.transactions),
                     currency: currency,
                     currentRate: currentRate)
    }
    func clone(balance: UInt64) -> State {
        return State(isStartFlowVisible: isStartFlowVisible,
                     isLoginRequired: isLoginRequired,
                     pinCreationStep: pinCreationStep,
                     paperPhraseStep: paperPhraseStep,
                     rootModal: rootModal,
                     pasteboard: pasteboard,
                     isModalDismissalBlocked: isModalDismissalBlocked,
                     walletState: WalletState(isConnected: walletState.isConnected, syncProgress: walletState.syncProgress, isSyncing: walletState.isSyncing, balance: balance, transactions: walletState.transactions),
                     currency: currency,
                     currentRate: currentRate)
    }
    func clone(transactions: [Transaction]) -> State {
        return State(isStartFlowVisible: isStartFlowVisible,
                     isLoginRequired: isLoginRequired,
                     pinCreationStep: pinCreationStep,
                     paperPhraseStep: paperPhraseStep,
                     rootModal: rootModal,
                     pasteboard: pasteboard,
                     isModalDismissalBlocked: isModalDismissalBlocked,
                     walletState: WalletState(isConnected: walletState.isConnected, syncProgress: walletState.syncProgress, isSyncing: walletState.isSyncing, balance: walletState.balance, transactions: transactions),
                     currency: currency,
                     currentRate: currentRate)
    }
    func clone(currency: Currency) -> State {
        return State(isStartFlowVisible: isStartFlowVisible,
                     isLoginRequired: isLoginRequired,
                     pinCreationStep: pinCreationStep,
                     paperPhraseStep: paperPhraseStep,
                     rootModal: rootModal,
                     pasteboard: pasteboard,
                     isModalDismissalBlocked: isModalDismissalBlocked,
                     walletState: walletState,
                     currency: currency,
                     currentRate: currentRate)
    }
    func clone(isLoginRequired: Bool) -> State {
        return State(isStartFlowVisible: isStartFlowVisible,
                     isLoginRequired: isLoginRequired,
                     pinCreationStep: pinCreationStep,
                     paperPhraseStep: paperPhraseStep,
                     rootModal: rootModal,
                     pasteboard: pasteboard,
                     isModalDismissalBlocked: isModalDismissalBlocked,
                     walletState: walletState,
                     currency: currency,
                     currentRate: currentRate)
    }
    func clone(currentRate: Rate) -> State {
        return State(isStartFlowVisible: isStartFlowVisible,
                     isLoginRequired: isLoginRequired,
                     pinCreationStep: pinCreationStep,
                     paperPhraseStep: paperPhraseStep,
                     rootModal: rootModal,
                     pasteboard: pasteboard,
                     isModalDismissalBlocked: isModalDismissalBlocked,
                     walletState: walletState,
                     currency: currency,
                     currentRate: currentRate)
    }
}
