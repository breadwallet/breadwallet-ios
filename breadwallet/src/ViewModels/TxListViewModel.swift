//
//  TxListViewModel.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2018-01-13.
//  Copyright © 2018 breadwallet LLC. All rights reserved.
//

import Foundation

/// View model of a transaction in list view
struct TxListViewModel: TxViewModel {
    
    // MARK: - Properties
    
    let tx: Transaction
    let statusText: String
    
    var address: String {
        if tx is EthLikeTransaction {
            return String(format: tx.direction.ethAddressTextFormat, tx.toAddress)
        } else {
            return String(format: tx.direction.addressTextFormat, tx.toAddress)
        }
    }
    
    var shouldDisplayAvailableToSpend: Bool {
        guard tx.currency is Bitcoin else { return false }
        return tx.status == .confirmed
    }
    
    // MARK: -
    
    func description(isBtcSwapped: Bool, rate: Rate, maxDigits: Int) -> NSAttributedString {
        var amount = ""
        
        // TODO:BCH move this logic into Amount/DisplayAmount?
        if let tx = tx as? BtcTransaction {
            amount = Amount(amount: tx.amount, rate: rate, maxDigits: maxDigits, currency: Currencies.btc).string(isBtcSwapped: isBtcSwapped)
        } else if let tx = tx as? EthTransaction {
            amount = DisplayAmount.ethString(value: tx.amount)
        } else {
            assertionFailure("unknown currency type")
        }
        
        let format = direction.amountDescriptionFormat
        let string = String(format: format, amount)
        return string.attributedStringForTags
    }
    
    // MARK: - Update Timer
    
    /// Returns (timestampString, shouldStartTimer)
    var timeSince: (String, Bool) {
        mutating get {
            if let cached = timeSinceCache {
                return cached
            }
            
            let result: (String, Bool)
            guard tx.timestamp > 0 else {
                result = (S.Transaction.justNow, false)
                timeSinceCache = result
                return result
            }
            let then = Date(timeIntervalSince1970: tx.timestamp)
            let now = Date()
            
            if !now.hasEqualYear(then) {
                let df = DateFormatter()
                df.setLocalizedDateFormatFromTemplate("dd/MM/yy")
                result = (df.string(from: then), false)
                timeSinceCache = result
                return result
            }
            
            if !now.hasEqualMonth(then) {
                let df = DateFormatter()
                df.setLocalizedDateFormatFromTemplate("MMM dd")
                result = (df.string(from: then), false)
                timeSinceCache = result
                return result
            }
            
            let difference = Int(Date().timeIntervalSince1970 - tx.timestamp)
            let secondsInMinute = 60
            let secondsInHour = 3600
            let secondsInDay = 86400
            let secondsInWeek = secondsInDay * 7
            if (difference < secondsInMinute) {
                result = (String(format: S.TimeSince.seconds, "\(difference)"), true)
            } else if difference < secondsInHour {
                result = (String(format: S.TimeSince.minutes, "\(difference/secondsInMinute)"), true)
            } else if difference < secondsInDay {
                result = (String(format: S.TimeSince.hours, "\(difference/secondsInHour)"), false)
            } else if difference < secondsInWeek {
                result = (String(format: S.TimeSince.days, "\(difference/secondsInDay)"), false)
            } else {
                let df = DateFormatter()
                df.setLocalizedDateFormatFromTemplate("MMM dd")
                result = (df.string(from: then), false)
            }
            if result.1 == false {
                timeSinceCache = result
            }
            return result
        }
    }
    
    private var timeSinceCache: (String, Bool)?
    
    // MARK: - Init
    
    init(tx: Transaction, walletManager: WalletManager) {
        self.tx = tx
        
        if let tx = tx as? BtcTransaction {
            self.statusText = TxListViewModel.makeStatus(tx: tx, walletManager: walletManager)
        } else {
            switch tx.status {
            case .pending:
                statusText = S.Transaction.pending
            case .confirmed, .complete:
                statusText = S.Transaction.complete
            default:
                statusText = S.Transaction.failed
            }
        }
    }
    
    /// Generate status display string
    private static func makeStatus(tx: BtcTransaction, walletManager: WalletManager) -> String {
        guard tx.isValid else {
            return S.Transaction.invalid
        }
        
        let confirms = tx.confirmations
        
        if confirms < 6 {
            var percentageString = ""
            switch confirms {
            case 0:
                var relayCount = 0
                if let txHash = tx.rawTransaction?.txHash,
                    let peerManager = walletManager.peerManager {
                    relayCount = peerManager.relayCount(txHash)
                }
                switch relayCount {
                case 0:
                    percentageString = "0%"
                case 1:
                    percentageString = "20%"
                default:
                    percentageString = "40%"
                }
                
            case 1:
                percentageString = "60%"
            case 2:
                percentageString = "80%"
            default:
                percentageString = "100%"
            }
            let format = tx.direction == .sent ? S.Transaction.sendingStatus : S.Transaction.receivedStatus
            return String(format: format, percentageString)
        } else {
            return S.Transaction.complete
        }
    }
}
