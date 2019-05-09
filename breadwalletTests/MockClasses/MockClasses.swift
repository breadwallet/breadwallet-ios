//
//  MockClasses.swift
//  breadwalletTests
//
//  Created by Ray Vander Veen on 2019-01-21.
//  Copyright © 2019 breadwallet LLC. All rights reserved.
//

import Foundation
import UIKit

@testable import breadwallet
@testable import BRCore

class MockTransaction: Transaction {
    var currency: Currency
    
    var hash: String
    
    var blockHeight: UInt64
    
    var confirmations: UInt64
    
    var status: TransactionStatus
    
    var direction: TransactionDirection
    
    var timestamp: TimeInterval
    
    var toAddress: String
    
    var amount: UInt256
    
    var mockIsValid: Bool
    
    var isValid: Bool {
        return mockIsValid
    }
    
    convenience init(timestamp: TimeInterval, direction: TransactionDirection, status: TransactionStatus) {
        self.init(valid: true)
        self.timestamp = timestamp
        self.direction = direction
        self.status = status
    }
    
    init(valid: Bool) {
        currency = MockCurrency()
        mockIsValid = valid
        hash = UUID.init().uuidString
        blockHeight = 100
        confirmations = 2
        status = .pending
        direction = .sent
        timestamp = Date().timeIntervalSince1970
        toAddress = UUID.init().uuidString
        amount = 0
    }
}

class MockCurrency: Currency {
    var name: String = ""
    
    var symbol: String = ""
    
    var code: String = ""
    
    var commonUnit: CurrencyUnit = MockCurrencyUnit()
    
    var colors: (UIColor, UIColor) = (UIColor(), UIColor())
    
    func isValidAddress(_ address: String) -> Bool {
        return true
    }
    
    var isSupported: Bool = false
    
    init() {
        
    }
}

class MockCurrencyUnit: CurrencyUnit {
    var decimals: Int = 0
    var name: String = ""
    
    init() {
        
    }
}

class MockTrackable: Trackable {
    
}
