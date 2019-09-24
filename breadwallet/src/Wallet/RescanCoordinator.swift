//
//  RescanCoordinator.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-01-07.
//  Copyright © 2017-2019 Breadwinner AG. All rights reserved.
//

import Foundation
import BRCrypto

/// Coordinates blockchain rescan for wallet managers
struct RescanCoordinator: Trackable {
    
    // 24-hours until incremental rescan is reset
    private static let incrementalRescanInterval: TimeInterval = C.secondsInDay
    
    static func initiateRescan(system: CoreSystem, wallet: Wallet) {
        guard let primaryWallet = wallet.networkPrimaryWallet else { return assertionFailure() }
        let manager = primaryWallet.manager
        let currency = primaryWallet.currency
        
        // Rescans go deeper each time they are initiated within a 24-hour period.
        //
        // 1. Rescan goes from the last-sent tx.
        // 2. Rescan from peer manager's last checkpoint.
        // 3. Full rescan from wallet creation date.
        
        var depth = WalletManagerSyncDepth.fromLastConfirmedSend

        if let prevRescan = UserDefaults.rescanState(for: currency) {
            if abs(prevRescan.startTime.timeIntervalSinceNow) > incrementalRescanInterval {
                depth = .fromLastConfirmedSend
            } else {
                depth = prevRescan.depth.deeper ?? .fromCreation
            }
        }
        
        UserDefaults.setRescanState(for: wallet.currency,
                                    to: RescanState(startTime: Date(), depth: depth))

        print("[\(currency.code)] initiating rescan from \(depth)")
        system.rescan(walletManager: manager, fromDepth: depth)
    }
}

/// Rescan state of a currency - stored in UserDefaults
struct RescanState: Codable {
    var startTime: Date
    var depth: WalletManagerSyncDepth = .fromLastConfirmedSend
}

extension WalletManagerSyncDepth: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let serialization = try container.decode(UInt8.self)
        guard let depth = WalletManagerSyncDepth(serialization: serialization) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "WalletManagerSyncDepth: unable to decode")
        }
        self = depth
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(serialization)
    }
}
