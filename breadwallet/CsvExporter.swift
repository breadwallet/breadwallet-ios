// 
//  CsvExporter.swift
//  breadwallet
//
//  Created by Drew Carlson on 2/5/21.
//  Copyright © 2021 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import Foundation
import WalletKit

class CsvExporter {
    static let instance = CsvExporter()

    private init() {
    }
    
    private let headerItems: [String] = [
        "currency_code",
        "timestamp",
        "transaction_id",
        "direction",
        "from_address",
        "to_address",
        "amount",
        "amount_unit",
        "fee",
        "fee_unit",
        "memo"
    ]
    
    func exportTransfers(wallets: [CurrencyId: Wallet]) -> URL? {
        let tempCsvDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("csv-export")
        
        do {
            let tempDir = try FileManager.default.url(
                for: .itemReplacementDirectory,
                in: .userDomainMask,
                appropriateFor: tempCsvDir,
                create: true)
            let tempCsvUrl = tempDir.appendingPathComponent("\(UUID().uuidString)-transactions.csv")
            let created = FileManager.default.createFile(atPath: tempCsvUrl.path, contents: nil, attributes: nil)
            
            assert(created)
            
            let fileHandle = try FileHandle(forWritingTo: tempCsvUrl)
            defer { fileHandle.closeFile() }
            fileHandle.writeRow(items: self.headerItems)
            fileHandle.writeWallets(wallets: wallets)
            fileHandle.closeFile()
            return tempCsvUrl
        } catch _ {
            return nil
        }
    }

}

private extension String {
    func forCsv() -> String {
        return "\"\(self)\""
    }
}

private extension FileHandle {
    func writeRow(items: [String]) {
        let line = items.joined(separator: ",")
        write("\(line)\n".data(using: .utf8)!)
    }
    
    func writeWallets(wallets: [CurrencyId: Wallet]) {
        // NOTE: Sorted for consistency with Android
        wallets.values
            .sorted { $0.currency.code < $1.currency.code }
            .forEach { wallet in writeWallet(wallet: wallet) }
    }
    
    private func writeWallet(wallet: Wallet) {
        let currencyCode = wallet.currency.code.lowercased().forCsv()
        // NOTE: Match WalletKitJava's natural sort order for Android compatibility
        wallet.transfers
            .sorted { $0.timestamp < $1.timestamp }
            .forEach { (transfer) in
                writeTransfer(currencyCode: currencyCode, transfer: transfer)
            }
    }
    
    private func writeTransfer(currencyCode: String, transfer: Transaction) {
        let timestamp: Date = Date.init(timeIntervalSince1970: transfer.timestamp)
        let fromAddress: String
        let amount: String
        let direction: String

        switch transfer.direction {
        case .sent:
            direction = "sent"
            var value = transfer.amount.tokenValue
            value.negate()
            amount = value.description
            fromAddress = transfer.currency.isBitcoinCompatible ? "" : transfer.fromAddress
        default:
            direction = "received"
            amount = transfer.amount.tokenValue.description
            fromAddress = transfer.fromAddress
        }
        
        // NOTE: Strip '0x' prefix for WalletKit versions below 9.x.x
        let hash: String = transfer.currency.isBitcoinCompatible && transfer.hash.hasPrefix("0x")
            ? String(transfer.hash.dropFirst(2)) : transfer.hash
        
        writeRow(items: [
            currencyCode,
            DateFormatter.iso8601Simple.string(from: timestamp).forCsv(),
            hash.forCsv(),
            direction.forCsv(),
            fromAddress.forCsv(),
            transfer.toAddress.forCsv(),
            amount,
            transfer.amount.currency.code.lowercased().forCsv(),
            transfer.fee.tokenValue.description,
            transfer.fee.currency.code.lowercased().forCsv(),
            transfer.metaData?.comment.forCsv() ?? "".forCsv()
        ])
    }
}
