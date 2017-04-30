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

    override init() {
        session = WCSession.default()
        super.init()
        session.delegate = self
        session.activate()
    }
}

extension PhoneWCSessionManager : WCSessionDelegate {

    func watchData(forWalletManager: WalletManager) -> WatchData {
        let wallet = forWalletManager.wallet!
        let image = UIImage.qrCode(data: "\(wallet.receiveAddress)".data(using: .utf8)!, color: CIColor(color: .black))?
            .resize(CGSize(width: 150.0, height: 150.0))!

        return WatchData(balance: String(wallet.balance/100),
                         localBalance: "$\(String(wallet.balance/C.satoshis*1300))",
                            receiveAddress: wallet.receiveAddress,
                            latestTransaction: "Latest transaction",
                            qrCode: image!,
                            transactions: [],
                            hasWallet: !forWalletManager.noWallet)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        guard let walletManager = walletManager else { return replyHandler(["error":"no wallet manager"])}
        guard let rawRequestType = message[AW_SESSION_REQUEST_TYPE] as? Int else { return replyHandler(["error":"unknown request type"]) }
        guard let requestType = AWSessionRequestType(rawValue: rawRequestType) else { return replyHandler(["error":"unknown request type"]) }
        guard let rawDataType = message[AW_SESSION_REQUEST_DATA_TYPE_KEY] as? Int else { return replyHandler(["error":"unknown data type"]) }
        guard let dataType = AWSessionRequestDataType(rawValue: rawDataType) else { return replyHandler(["error":"unknown data type"]) }

        if case .fetchData = requestType {
            switch dataType {
            case .applicationContextData:
                let data = watchData(forWalletManager: walletManager).toDictionary
                replyHandler([AW_SESSION_RESPONSE_KEY: data])
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
