//
//  PigeonRequest.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2018-07-27.
//  Copyright © 2018-2019 Breadwinner AG. All rights reserved.
//

import Foundation

enum PigeonRequestType {
    case payment
    case call
}

protocol PigeonRequest {
    var currency: Currency { get }
    var address: String { get }
    var purchaseAmount: Amount { get }
    var memo: String { get }
    var type: PigeonRequestType { get }
    var abiData: String? { get }
    var txSize: UInt64? { get } // gas limit
    var txFee: Amount? { get } // gas price
}

private struct AssociatedKeys {
    static var responseCallback = "responseCallback"
}

private class CallbackWrapper: NSObject, NSCopying {

    init(_ callback: @escaping (CheckoutResult) -> Void) {
        self.callback = callback
    }

    let callback: (CheckoutResult) -> Void

    func copy(with zone: NSZone? = nil) -> Any {
        return CallbackWrapper(callback)
    }
}

extension PigeonRequest {

    var responseCallback: ((CheckoutResult) -> Void)? {
        get {
            guard let callbackWrapper = objc_getAssociatedObject(self, &AssociatedKeys.responseCallback) as? CallbackWrapper else { return nil }
            return callbackWrapper.callback
        }
        set {
            guard let newValue = newValue else { return }
            objc_setAssociatedObject(self, &AssociatedKeys.responseCallback, CallbackWrapper(newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    func getToken(completion: @escaping (Currency?) -> Void) {
        assertionFailure()
    }
}

class MessagePaymentRequestWrapper: PigeonRequest {
    private let paymentRequest: MessagePaymentRequest

    init(paymentRequest: MessagePaymentRequest, currency: Currency) {
        self.paymentRequest = paymentRequest
        self.currency = currency
    }

    var currency: Currency

    var purchaseAmount: Amount {
        return Amount(tokenString: paymentRequest.amount, currency: currency, unit: currency.baseUnit)
    }

    var type: PigeonRequestType {
        return .payment
    }

    var abiData: String? {
        return nil
    }
    
    var address: String {
        return paymentRequest.address
    }
    
    var memo: String {
        return paymentRequest.memo
    }
    
    var txSize: UInt64? {
        return paymentRequest.hasTransactionSize ? UInt64(paymentRequest.transactionSize) : 100000
    }
    
    var txFee: Amount? {
        return paymentRequest.hasTransactionFee ? Amount(tokenString: paymentRequest.transactionFee, currency: currency, unit: currency.baseUnit) : nil
    }
}

class MessageCallRequestWrapper: PigeonRequest {

    private let callRequest: MessageCallRequest

    init(callRequest: MessageCallRequest, currency: Currency) {
        self.callRequest = callRequest
        self.currency = currency
    }

    var currency: Currency

    var purchaseAmount: Amount {
        return Amount(tokenString: callRequest.amount, currency: currency, unit: currency.baseUnit)
    }

    var type: PigeonRequestType {
        return .call
    }

    var abiData: String? {
        return callRequest.abi
    }
    
    var address: String {
        return callRequest.address
    }
    
    var memo: String {
        return callRequest.memo
    }
    
    var txSize: UInt64? {
        return callRequest.hasTransactionSize ? UInt64(callRequest.transactionSize) : 200000
    }
    
    var txFee: Amount? {
        return callRequest.hasTransactionFee ? Amount(tokenString: callRequest.transactionFee, currency: currency, unit: currency.baseUnit) : nil
    }
}
