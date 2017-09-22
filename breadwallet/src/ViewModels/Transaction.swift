//
//  Transaction.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-11-17.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit
import BRCore

//Ideally this would be a struct, but it needs to be a class to allow
//for lazy variables
class Transaction {

    //MARK: - Public
    init?(_ tx: BRTxRef, walletManager: WalletManager, kvStore: BRReplicatedKVStore?, rate: Rate?) {
        guard let wallet = walletManager.wallet else { return nil }
        guard let peerManager = walletManager.peerManager  else { return nil }

        self.tx = tx
        self.wallet = wallet
        self.kvStore = kvStore

        let fee = wallet.feeForTx(tx) ?? 0
        self.fee = fee

        let amountReceived = wallet.amountReceivedFromTx(tx)
        let amountSent = wallet.amountSentByTx(tx)

        if amountSent > 0 && (amountReceived + fee) == amountSent {
            self.direction = .moved
            self.satoshis = amountSent
        } else if amountSent > 0 {
            self.direction = .sent
            self.satoshis = amountSent - amountReceived - fee
        } else {
            self.direction = .received
            self.satoshis = amountReceived
        }
        self.timestamp = Int(tx.pointee.timestamp)

        self.isValid = wallet.transactionIsValid(tx)
        let transactionBlockHeight = tx.pointee.blockHeight
        self.blockHeight = tx.pointee.blockHeight == UInt32(INT32_MAX) ? S.TransactionDetails.notConfirmedBlockHeightLabel : "\(tx.pointee.blockHeight)"

        let blockHeight = peerManager.lastBlockHeight
        confirms = transactionBlockHeight > blockHeight ? 0 : Int(blockHeight - transactionBlockHeight) + 1
        self.status = makeStatus(tx, wallet: wallet, peerManager: peerManager, confirms: confirms, direction: self.direction)

        self.hash = tx.pointee.txHash.description
        self.metaDataKey = tx.pointee.txHash.txKey

        if let rate = rate, confirms < 6 && direction == .received {
            attemptCreateMetaData(tx: tx, rate: rate)
        }

    }

    func amountDescription(isBtcSwapped: Bool, rate: Rate, maxDigits: Int) -> String {
        let amount = Amount(amount: satoshis, rate: rate, maxDigits: maxDigits)
        return isBtcSwapped ? amount.localCurrency : amount.bits
    }

    func descriptionString(isBtcSwapped: Bool, rate: Rate, maxDigits: Int) -> NSAttributedString {
        let amount = Amount(amount: satoshis, rate: rate, maxDigits: maxDigits).string(isBtcSwapped: isBtcSwapped)
        let format = direction.amountDescriptionFormat
        let string = String(format: format, amount)
        return string.attributedStringForTags
    }

    var detailsAddressText: String {
        let address = toAddress?.largeCondensed
        return String(format: direction.addressTextFormat, address ?? S.TransactionDetails.account)
    }

    func amountDetails(isBtcSwapped: Bool, rate: Rate, rates: [Rate], maxDigits: Int) -> String {
        let feeAmount = Amount(amount: fee, rate: rate, maxDigits: maxDigits)
        let feeString = direction == .sent ? String(format: S.Transaction.fee, "\(feeAmount.string(isBtcSwapped: isBtcSwapped))") : ""
        let amountString = "\(direction.sign)\(Amount(amount: satoshis, rate: rate, maxDigits: maxDigits).string(isBtcSwapped: isBtcSwapped)) \(feeString)"
        var startingString = String(format: S.Transaction.starting, "\(Amount(amount: startingBalance, rate: rate, maxDigits: maxDigits).string(isBtcSwapped: isBtcSwapped))")
        var endingString = String(format: String(format: S.Transaction.ending, "\(Amount(amount: balanceAfter, rate: rate, maxDigits: maxDigits).string(isBtcSwapped: isBtcSwapped))"))

        if startingBalance > C.maxMoney {
            startingString = ""
            endingString = ""
        }

        var exchangeRateInfo = ""
        if let metaData = metaData, let currentRate = rates.filter({ $0.code.lowercased() == metaData.exchangeRateCurrency.lowercased() }).first {
            let difference = (currentRate.rate - metaData.exchangeRate)/metaData.exchangeRate*100.0
            let prefix = difference > 0.0 ? "+" : "-"
            let firstLine = direction == .sent ? S.Transaction.exchangeOnDaySent : S.Transaction.exchangeOnDayReceived
            let nf = NumberFormatter()
            nf.currencySymbol = currentRate.currencySymbol
            nf.numberStyle = .currency
            if let rateString = nf.string(from: metaData.exchangeRate as NSNumber) {
                let secondLine = "\(rateString)/btc \(prefix)\(String(format: "%.2f", difference))%"
                exchangeRateInfo = "\(firstLine)\n\(secondLine)"
            }
        }

        return "\(amountString)\n\n\(startingString)\n\(endingString)\n\n\(exchangeRateInfo)"
    }

    let direction: TransactionDirection
    let status: String
    let timestamp: Int
    let fee: UInt64
    let hash: String
    let isValid: Bool
    let blockHeight: String
    private let confirms: Int
    private let metaDataKey: String

    //MARK: - Private
    private let tx: BRTxRef
    private let wallet: BRWallet
    fileprivate let satoshis: UInt64
    private var kvStore: BRReplicatedKVStore?
    
    lazy var toAddress: String? = {
        switch self.direction {
        case .sent:
            guard let output = self.tx.outputs.filter({ output in
                !self.wallet.containsAddress(output.swiftAddress)
            }).first else { return nil }
            return output.swiftAddress
        case .received:
            guard let output = self.tx.outputs.filter({ output in
                self.wallet.containsAddress(output.swiftAddress)
            }).first else { return nil }
            return output.swiftAddress
        case .moved:
            guard let output = self.tx.outputs.filter({ output in
                self.wallet.containsAddress(output.swiftAddress)
            }).first else { return nil }
            return output.swiftAddress
        }
    }()

    var exchangeRate: Double? {
        return metaData?.exchangeRate
    }

    var comment: String? {
        return metaData?.comment
    }

    var hasKvStore: Bool {
        return kvStore != nil
    }

    var _metaData: TxMetaData?
    var metaData: TxMetaData? {
        if _metaData != nil {
            return _metaData
        } else {
            guard let kvStore = self.kvStore else { return nil }
            if let data = TxMetaData(txKey: self.metaDataKey, store: kvStore) {
                _metaData = data
                return _metaData
            } else {
                return nil
            }
        }
    }

    private var balanceAfter: UInt64 {
        return wallet.balanceAfterTx(tx)
    }

    private lazy var startingBalance: UInt64 = {
        switch self.direction {
        case .received:
            return
                self.balanceAfter.subtractingReportingOverflow(self.satoshis).0.subtractingReportingOverflow(self.fee).0
        case .sent:
            return self.balanceAfter.addingReportingOverflow(self.satoshis).0.addingReportingOverflow(self.fee).0
        case .moved:
            return self.balanceAfter.addingReportingOverflow(self.fee).0
        }
    }()

    // return: (timestampString, shouldStartTimer)
    var timeSince: (String, Bool) {
        if let cached = timeSinceCache {
            return cached
        }

        let result: (String, Bool)
        guard timestamp > 0 else {
            result = (S.Transaction.justNow, false)
            timeSinceCache = result
            return result
        }
        let then = Date(timeIntervalSince1970: TimeInterval(timestamp))
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

        let difference = Int(Date().timeIntervalSince1970) - timestamp
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

    private var timeSinceCache: (String, Bool)?

    var longTimestamp: String {
        guard timestamp > 0 else { return wallet.transactionIsValid(tx) ? S.Transaction.justNow : "" }
        let date = Date(timeIntervalSince1970: Double(timestamp))
        return Transaction.longDateFormatter.string(from: date)
    }

    var rawTransaction: BRTransaction {
        return tx.pointee
    }

    var isPending: Bool {
        return confirms < 6
    }

    static let longDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.setLocalizedDateFormatFromTemplate("MMMM d, yyy h:mm a")
        return df
    }()

    private func attemptCreateMetaData(tx: BRTxRef, rate: Rate) {
        guard metaData == nil else { return }
        let newData = TxMetaData(transaction: tx.pointee,
                                          exchangeRate: rate.rate,
                                          exchangeRateCurrency: rate.code,
                                          feeRate: 0.0,
                                          deviceId: UserDefaults.standard.deviceID)
        do {
            let _ = try kvStore?.set(newData)
        } catch let error {
            print("could not update metadata: \(error)")
        }
    }

    var shouldDisplayAvailableToSpend: Bool {
        return confirms > 1 && confirms < 6 && direction == .received
    }
}

private extension String {
    var smallCondensed: String {
        let start = String(self[..<index(startIndex, offsetBy: 5)])
        let end = String(self[index(endIndex, offsetBy: -5)...])
        return start + "..." + end
    }

    var largeCondensed: String {
        let start = String(self[..<index(startIndex, offsetBy: 10)])
        let end = String(self[index(endIndex, offsetBy: -10)...])
        return start + "..." + end
    }
}

private func makeStatus(_ txRef: BRTxRef, wallet: BRWallet, peerManager: BRPeerManager, confirms: Int, direction: TransactionDirection) -> String {
    let tx = txRef.pointee
    guard wallet.transactionIsValid(txRef) else {
        return S.Transaction.invalid
    }

    if confirms < 6 {
        var percentageString = ""
        if confirms == 0 {
            let relayCount = peerManager.relayCount(tx.txHash)
            if relayCount == 0 {
                percentageString = "0%"
            } else if relayCount == 1 {
                percentageString = "20%"
            } else if relayCount > 1 {
                percentageString = "40%"
            }
        } else if confirms == 1 {
            percentageString = "60%"
        } else if confirms == 2 {
            percentageString = "80%"
        } else if confirms > 2 {
            percentageString = "100%"
        }
        let format = direction == .sent ? S.Transaction.sendingStatus : S.Transaction.receivedStatus
        return String(format: format, percentageString)
    } else {
        return S.Transaction.complete
    }
}

extension Transaction : Equatable {}

func ==(lhs: Transaction, rhs: Transaction) -> Bool {
    return lhs.hash == rhs.hash && lhs.status == rhs.status && lhs.comment == rhs.comment && lhs.hasKvStore == rhs.hasKvStore
}
