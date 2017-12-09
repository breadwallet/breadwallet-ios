//
//  BRAPIClient+Crowdsale.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-12-04.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation

enum KYCStatus {
    case none
    case pending
    case failed
    case complete

    var description: String {
        switch self {
        case .none:
            return "Verification not complete"
        case .pending:
            return "Pending Verification"
        case .failed:
            return "Failed Verification"
        case .complete:
            return "Verification succeeded"
        }
    }
}

struct RegistrationParams : Codable {
    let first_name: String
    let last_name: String
    let email: String
    let redirect_uri: String
    let country: String
}

fileprivate struct KycResponse : Codable {
    let status: String
    let form_url: String
}

extension BRAPIClient {

    func register(params: RegistrationParams, callback: @escaping ((URL?) -> Void)) {

        let encodedData = try? JSONEncoder().encode(params)
        var req = URLRequest(url: url("/kyc"))
        req.httpMethod = "POST"
        req.httpBody = encodedData
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        let task = dataTaskWithRequest(req, authenticated: true, retryCount: 0, handler: { (data, response, error) in
            if error == nil {
                if let data = data {
                    if let responseObject = try? JSONDecoder().decode(KycResponse.self, from: data) {
                        if let url = URL(string: responseObject.form_url) {
                            return callback(url)
                        }
                    }
                }
            } else {
                print("error: \(error)")
            }

            return callback(nil)
        })
        task.resume()
    }

    func kycStatus(contractAddress: String, ethAddress: String, callback: @escaping (_ status: KYCStatus) -> Void) {
        let network = E.isTestnet ? "ropsten" : "mainnet"
        let req = URLRequest(url: url("/kyc?contract_address=\(contractAddress)&ethereum_address=\(ethAddress)&network=\(network)"))
        let task = dataTaskWithRequest(req, authenticated: true) { (data, response, err) in
            if err == nil, let data = data {
                do {
                    if let status = try? JSONDecoder().decode(KYCStatusResponse.self, from: data) {
                        if status.status == "complete" {
                            return callback(.complete)
                        } else if status.status == "pending" {
                            return callback(.pending)
                        } else if status.status == "failed" {
                            return callback(.failed)
                        }
                    }
                } catch (let e) {
                    self.log("kycStatus: error parsing json \(e)")
                }
            }
            return callback(.none)
        }
        task.resume()
    }

}

fileprivate struct KYCStatusResponse : Codable {
    let status: String
}
