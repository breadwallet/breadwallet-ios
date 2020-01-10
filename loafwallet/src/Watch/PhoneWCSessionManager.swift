//
//  PhoneWCSessionManager.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-04-27.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import UIKit
import WatchConnectivity

class PhoneWCSessionManager : NSObject {
    private let session: WCSession

    var walletManager: WalletManager?
    var rate: Rate?

    override init() {
        session = WCSession.default
        super.init()
        session.delegate = self
        session.activate()
        listenForSeedChange()
    }

    func listenForSeedChange() {
        NotificationCenter.default.addObserver(forName: .WalletDidWipeNotification, object: nil, queue: nil, using: { _ in
            self.session.sendMessage([AW_SESSION_RESPONSE_KEY: "didWipe"], replyHandler: nil, errorHandler: nil)
        })
    }
}

extension PhoneWCSessionManager : WCSessionDelegate {

    func watchData(forWalletManager: WalletManager, rate: Rate) -> WatchData? {
        if let noWallet = walletManager?.noWallet, noWallet == true {
            return WatchData(balance: "", localBalance: "", receiveAddress: "", latestTransaction: "", qrCode: UIImage(), transactions: [], hasWallet: false)
        }

        guard let wallet = forWalletManager.wallet else { return nil }

        let amount = Amount(amount: wallet.balance, rate: rate, maxDigits: 2) //TODO - fix always bits on watch

        let image = UIImage.qrCode(data: "\(wallet.receiveAddress)".data(using: .utf8)!, color: CIColor(color: .black))?
            .resize(CGSize(width: 136.0, height: 136.0))!

        return WatchData(balance: amount.bits,
                         localBalance: amount.localCurrency,
                            receiveAddress: wallet.receiveAddress,
                            latestTransaction: "Latest transaction",
                            qrCode: image!,
                            transactions: [],
                            hasWallet: !forWalletManager.noWallet)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        guard let walletManager = walletManager else { return replyHandler(["error": "no wallet manager"])}
        guard let rate = rate else { return replyHandler(["error": "rate not set"]) }
        guard let rawRequestType = message[AW_SESSION_REQUEST_TYPE] as? Int else { return replyHandler(["error":"unknown request type"]) }
        guard let requestType = AWSessionRequestType(rawValue: rawRequestType) else { return replyHandler(["error":"unknown request type"]) }
        guard let rawDataType = message[AW_SESSION_REQUEST_DATA_TYPE_KEY] as? Int else { return replyHandler(["error":"unknown data type"]) }
        guard let dataType = AWSessionRequestDataType(rawValue: rawDataType) else { return replyHandler(["error":"unknown data type"]) }

        if case .fetchData = requestType {
            switch dataType {
            case .applicationContextData:
                if let data = watchData(forWalletManager: walletManager, rate: rate) {
                    replyHandler([AW_SESSION_RESPONSE_KEY: data.toDictionary])
                } else {
                    replyHandler(["error": "unable to generate data"])
                }
            case .qrCodeBits:
                replyHandler([:])
            }
        } else {
            replyHandler(["error":"unknown request type"])
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("did complete activation")
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        print("did become inactive")
    }

    func sessionDidDeactivate(_ session: WCSession) {
        print("did deactivate")
    }
}
