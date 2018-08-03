//
//  PigeonRequest.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2018-07-27.
//  Copyright © 2018 breadwallet LLC. All rights reserved.
//

import Foundation
import BRCore

enum PigeonRequestType {
    case payment
    case call
}

protocol PigeonRequest {
    var currency: CurrencyDef { get }
    var address: String { get }
    var purchaseAmount: Amount { get }
    var memo: String { get }
    var type: PigeonRequestType { get }
    var abiData: String? { get }
    var txSize: UInt256? { get }
    var txFee: Amount? { get }
}

private struct AssociatedKeys {
    static var responseCallback = "responseCallback"
}

private class CallbackWrapper : NSObject, NSCopying {

    init(_ callback: @escaping (SendResult) -> Void) {
        self.callback = callback
    }

    let callback: (SendResult) -> Void

    func copy(with zone: NSZone? = nil) -> Any {
        return CallbackWrapper(callback)
    }
}


extension PigeonRequest {

    var responseCallback: ((SendResult) -> Void)? {
        get {
            guard let callbackWrapper = objc_getAssociatedObject(self, &AssociatedKeys.responseCallback) as? CallbackWrapper else { return nil }
            return callbackWrapper.callback
        }
        set {
            guard let newValue = newValue else { return }
            objc_setAssociatedObject(self, &AssociatedKeys.responseCallback, CallbackWrapper(newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

extension MessagePaymentRequest: PigeonRequest {

    var currency: CurrencyDef {
        return Currencies.eth
    }

    var purchaseAmount: Amount {
        return Amount(amount: UInt256(string: amount), currency: currency)
    }

    var type: PigeonRequestType {
        return .payment
    }

    var abiData: String? {
        return nil
    }
    
    var txSize: UInt256? {
        return hasTransactionSize ? UInt256(string: transactionSize) : nil
    }
    
    var txFee: Amount? {
        return hasTransactionFee ? Amount(amount: UInt256(string: transactionFee), currency: currency) : nil
    }
}

extension MessageCallRequest: PigeonRequest {

    var currency: CurrencyDef {
        return Currencies.eth
    }

    var purchaseAmount: Amount {
        return Amount(amount: UInt256(string: amount), currency: currency)
    }

    var type: PigeonRequestType {
        return .call
    }

    var abiData: String? {
        return abi
    }
    
    var txSize: UInt256? {
        return hasTransactionSize ? UInt256(string: transactionSize) : nil
    }
    
    var txFee: Amount? {
        return hasTransactionFee ? Amount(amount: UInt256(string: transactionFee), currency: currency) : nil
    }
}
