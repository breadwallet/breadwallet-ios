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
        let blockHeight = peerManager.lastBlockHeight
        confirms = transactionBlockHeight > blockHeight ? 0 : Int(blockHeight - transactionBlockHeight) + 1
        self.status = makeStatus(tx, wallet: wallet, peerManager: peerManager, confirms: confirms, direction: self.direction)

        self.hash = tx.pointee.txHash.description

        if let rate = rate, confirms < 6 {
            attemptCreateMetaData(tx: tx, rate: rate)
        }
    }

    func amountDescription(isBtcSwapped: Bool, rate: Rate, maxDigits: Int) -> String {
        let amount = Amount(amount: satoshis, rate: rate, maxDigits: maxDigits)
        return isBtcSwapped ? amount.localCurrency : amount.bits
    }

    func descriptionString(isBtcSwapped: Bool, rate: Rate, maxDigits: Int) -> NSAttributedString {
        let amount = Amount(amount: satoshis, rate: rate, maxDigits: maxDigits).string(isBtcSwapped: isBtcSwapped)
        let format = direction.descriptionFormat

        var address = toAddress
        if let theAddress = address {
            let start = theAddress.substring(to: theAddress.index(theAddress.startIndex, offsetBy: 5))
            let end = theAddress.substring(from: theAddress.index(theAddress.endIndex, offsetBy: -5))
            address = start + "..." + end
        }
        let string = String(format: format, amount, address ?? S.TransactionDetails.account)
        return string.attributedStringForTags
    }

    func amountDetails(isBtcSwapped: Bool, rate: Rate, rates: [Rate], maxDigits: Int) -> String {
        let feeAmount = Amount(amount: fee, rate: rate, maxDigits: maxDigits)
        let feeString = direction == .sent ? String(format: S.Transaction.fee, "\(feeAmount.string(isBtcSwapped: isBtcSwapped))") : ""
        let amountString = "\(direction.sign)\(Amount(amount: satoshis, rate: rate, maxDigits: maxDigits).string(isBtcSwapped: isBtcSwapped)) \(feeString)"
        let startingString = String(format: S.Transaction.starting, "\(Amount(amount: startingBalance, rate: rate, maxDigits: maxDigits).string(isBtcSwapped: isBtcSwapped))")
        let endingString = String(format: String(format: S.Transaction.ending, "\(Amount(amount: balanceAfter, rate: rate, maxDigits: maxDigits).string(isBtcSwapped: isBtcSwapped))"))

        var exchangeRateInfo = ""
        if let metaData = metaData, let currentRate = rates.filter({ $0.code.lowercased() == metaData.exchangeRateCurrency.lowercased() }).first{
            let difference = (currentRate.rate - metaData.exchangeRate)/metaData.exchangeRate*100.0
            let prefix = difference > 0.0 ? "+" : "-"
            let firstLine = S.Transaction.exchangeOnDay
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
    private let confirms: Int

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
        let then = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let now = Date()

        if !now.hasEqualYear(then) {
            let df = DateFormatter()
            df.setLocalizedDateFormatFromTemplate("dd/MM/yy")
            return df.string(from: then)
        }

        if !now.hasEqualMonth(then) {
            let df = DateFormatter()
            df.setLocalizedDateFormatFromTemplate("MMM dd")
            return df.string(from: then)
        }

        let difference = Int(Date().timeIntervalSince1970) - timestamp
        let secondsInMinute = 60
        let secondsInHour = 3600
        let secondsInDay = 86400
        let secondsInWeek = secondsInDay * 7
        if (difference < secondsInMinute) {
            return String(format: S.TimeSince.seconds, "\(difference)")
        } else if difference < secondsInHour {
            return String(format: S.TimeSince.minutes, "\(difference/secondsInMinute)")
        } else if difference < secondsInDay {
            return String(format: S.TimeSince.hours, "\(difference/secondsInHour)")
        } else if difference < secondsInWeek {
            return String(format: S.TimeSince.days, "\(difference/secondsInDay)")
        } else {
            let df = DateFormatter()
            df.setLocalizedDateFormatFromTemplate("MMM dd")
            return df.string(from: then)
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

    var shouldDisplayAvailableToSpend: Bool {
        return confirms > 1 && confirms < 6 && direction == .received
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
    return lhs.hash == rhs.hash && lhs.status == rhs.status
}
