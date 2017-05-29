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
    init(_ tx: BRTxRef, wallet: BRWallet, blockHeight: UInt32, kvStore: BRReplicatedKVStore?, rate: Rate?) {
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
        let transactionIsVerified = wallet.transactionIsVerified(tx)
        let transactionIsPending = wallet.transactionIsPending(tx)

        confirms = transactionBlockHeight > blockHeight ? 0 : Int((blockHeight - transactionBlockHeight) + 1)
        self.status = makeStatus(isValid: isValid, isPending: transactionIsPending, isVerified: transactionIsVerified, confirms: confirms)

        if isValid {
            self.longStatus = confirms > 6 ? S.Transaction.complete : S.Transaction.waiting
        } else {
            self.longStatus = S.Transaction.invalid
        }

        self.hash = tx.pointee.txHash.description

        if let rate = rate, confirms < 6 {
            attemptCreateMetaData(tx: tx, rate: rate)
        }
    }

    func amountDescription(isBtcSwapped: Bool, rate: Rate) -> String {
        let amount = Amount(amount: satoshis, rate: rate)
        return isBtcSwapped ? amount.localCurrency : amount.bits
    }

    func descriptionString(isBtcSwapped: Bool, rate: Rate) -> NSAttributedString {
        let amount = Amount(amount: satoshis, rate: rate).string(isBtcSwapped: isBtcSwapped)
        let format = direction.descriptionFormat
        let string = String(format: format, amount, S.TransactionDetails.account)
        return string.attributedStringForTags
    }

    func amountDetails(isBtcSwapped: Bool, rate: Rate) -> String {
        let feeAmount = Amount(amount: fee, rate: rate)
        let feeString = direction == .sent ? String(format: S.Transaction.fee, "\(feeAmount.string(isBtcSwapped: isBtcSwapped))") : ""
        let amountString = "\(direction.sign)\(Amount(amount: satoshis, rate: rate).string(isBtcSwapped: isBtcSwapped)) \(feeString)"
        let startingString = String(format: S.Transaction.starting, "\(Amount(amount: startingBalance, rate: rate).string(isBtcSwapped: isBtcSwapped))")
        let endingString = String(format: String(format: S.Transaction.ending, "\(Amount(amount: balanceAfter, rate: rate).string(isBtcSwapped: isBtcSwapped))"))

        var exchangeRateInfo = ""
        if let metaData = metaData {
            let difference = (rate.rate - metaData.exchangeRate)/metaData.exchangeRate*100.0
            let prefix = difference > 0.0 ? "+" : "-"
            let firstLine = S.Transaction.exchangeOnDay
            let secondLine = String(format: S.Transaction.exchange, "$\(metaData.exchangeRate)/btc \(prefix)\(String(format: "%.2f", difference))%")
            exchangeRateInfo = "\(firstLine)\n\(secondLine)"
        }

        return "\(amountString)\n\n\(startingString)\n\(endingString)\n\n\(exchangeRateInfo)"
    }

    let direction: TransactionDirection
    let status: String
    let longStatus: String
    let timestamp: Int
    let fee: UInt64
    let hash: String
    let isValid: Bool
    let confirms: Int

    //MARK: - Private
    private let tx: BRTxRef
    private let wallet: BRWallet
    fileprivate let satoshis: UInt64
    private var kvStore: BRReplicatedKVStore?
    
    lazy var toAddress: String? = {
        switch self.direction {
        case .sent:
            guard let output = self.tx.pointee.swiftOutputs.filter({ output in
                !self.wallet.containsAddress(output.swiftAddress)
            }).first else { return nil }
            return output.swiftAddress
        case .received:
            guard let output = self.tx.pointee.swiftOutputs.filter({ output in
                self.wallet.containsAddress(output.swiftAddress)
            }).first else { return nil }
            return output.swiftAddress
        case .moved:
            guard let output = self.tx.pointee.swiftOutputs.filter({ output in
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

    var _metaData: BRTxMetadataObject?
    var metaData: BRTxMetadataObject? {
        if _metaData != nil {
            return _metaData
        } else {
            guard let kvStore = self.kvStore else { return nil }
            if let data = BRTxMetadataObject(txHash: self.tx.pointee.txHash, store: kvStore) {
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
            return self.balanceAfter - self.satoshis - self.fee
        case .sent:
            return self.balanceAfter + self.satoshis + self.fee
        case .moved:
            return self.balanceAfter + self.fee
        }
    }()

    var timeSince: String {
        guard timestamp > 0 else { return S.Transaction.justNow }
        let difference = Int(Date().timeIntervalSince1970) - timestamp
        let secondsInMinute = 60
        let secondsInHour = 3600
        let secondsInDay = 86400
        if (difference < secondsInMinute) {
            return "\(difference) s"
        } else if difference < secondsInHour {
            return "\(difference/secondsInMinute) m"
        } else if difference < secondsInDay {
            return "\(difference/secondsInHour) h"
        } else {
            return "\(difference/secondsInDay) d"
        }
    }

    var longTimestamp: String {
        guard timestamp > 0 else { return wallet.transactionIsValid(tx) ? S.Transaction.justNow : "" }
        let date = Date(timeIntervalSince1970: Double(timestamp))
        return longDateFormatter.string(from: date)
    }

    var rawTransaction: BRTransaction {
        return tx.pointee
    }

    var isPending: Bool {
        return confirms < 6
    }

    private let longDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "MMMM d, yyy 'at' h:mm a"
        return df
    }()

    private func attemptCreateMetaData(tx: BRTxRef, rate: Rate) {
        guard metaData == nil else { return }
        let newData = BRTxMetadataObject(transaction: tx.pointee,
                                          exchangeRate: rate.rate,
                                          exchangeRateCurrency: rate.currencySymbol,
                                          feeRate: 0.0,
                                          deviceId: UserDefaults.standard.deviceID)
        do {
            let _ = try kvStore?.set(newData)
        } catch let error {
            print("could not update metadata: \(error)")
        }
    }
}

private func makeStatus(isValid: Bool, isPending: Bool, isVerified: Bool, confirms: Int) -> String {
    if confirms == 0 && !isValid {
        return "INVALID"
    } else if confirms == 0 && isPending {
        return "Pending"
    } else if confirms == 0 && !isVerified {
        return "Unverified"
    } else if confirms < 6 {
        if confirms == 0 {
            return "0 confirmations"
        } else if confirms == 1 {
            return "1 confirmation"
        } else {
            return "\(confirms) confirmations"
        }
    } else {
        return "Complete"
    }
}

extension Transaction : Equatable {}

func ==(lhs: Transaction, rhs: Transaction) -> Bool {
    return lhs.hash == rhs.hash && lhs.status == rhs.status
}
