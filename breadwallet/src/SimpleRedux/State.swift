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
    let pinCreationStep: PinCreationStep
    let paperPhraseStep: PaperPhraseStep
    let rootModal: RootModal
    let pasteboard: String?
}

extension State {
    static var initial: State {
        return State(   isStartFlowVisible: false,
                        pinCreationStep:    .none,
                        paperPhraseStep:    .none,
                        rootModal:          .none,
                        pasteboard:         UIPasteboard.general.string)
    }
}

enum PinCreationStep {
    case none
    case start
    case confirm(pin: String)
    case confirmFail(pin: String)
    case save(pin: String)
}

enum PaperPhraseStep {
    case none
    case start
    case write
    case confirm
    case confirmed
}

enum RootModal {
    case none
    case send
    case receive
    case menu

    func viewController(store: Store) -> UIViewController? {
        switch self {
            case .none:
                return nil
            case .send:
                return ModalViewController(childViewController: SendViewController(store: store))
            case .receive:
                return ModalViewController(childViewController: ReceiveViewController(store: store))
            case .menu:
                return ModalViewController(childViewController: MenuViewController())
        }
    }
}

extension PinCreationStep: Equatable {}

func ==(lhs: PinCreationStep, rhs: PinCreationStep) -> Bool {
    switch (lhs, rhs) {
        case (.none, .none):
            return true
        case (.start, .start):
            return true
        case (.confirm(let leftPin), .confirm(let rightPin)):
            return leftPin == rightPin
        case (.save(let leftPin), .save(let rightPin)):
            return leftPin == rightPin
        case (.confirmFail(let leftPin), .confirmFail(let rightPin)):
            return leftPin == rightPin
        default:
            return false
    }
}
