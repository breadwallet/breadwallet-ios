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
    case incomplete
    case pending
    case retry
    case failed
    case complete

    var description: String {
        switch self {
        case .none:
            return "Verification not complete"
        case .incomplete:
            return "Registration form not complete"
        case .pending:
            return "Pending Verification"
        case .retry:
            return "Failed Verification. Please Retry"
        case .failed:
            return "Failed Verification"
        case .complete:
            return "Verification succeeded"
        }
    }
}

extension KYCStatus {
    init?(string: String) {
        switch string.lowercased() {
        case "none": self = .none
        case "incomplete": self = .incomplete
        case "pending": self = .pending
        case "retry": self = .retry
        case "failed": self = .failed
        case "complete": self = .complete
        default: return nil
        }
    }
}

struct RegistrationParams : Codable {
    let first_name: String
    let last_name: String
    let email: String
    let redirect_uri: String
    let country: String
    let contract_address: String
    let ethereum_address: String
    let network: String = E.isTestnet ? "ropsten" : "mainnet"
}

extension BRAPIClient {

    func register(params: RegistrationParams, callback: @escaping ((URL?) -> Void)) {

        let encodedData = try? JSONEncoder().encode(params)
        var req = URLRequest(url: url("/kyc/networks/\(params.network)/contracts/\(params.contract_address)"))
        req.httpMethod = "POST"
        req.httpBody = encodedData
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        let task = dataTaskWithRequest(req, authenticated: true, retryCount: 0, handler: { (data, response, error) in
            if error == nil {
                if let data = data {
                    if let responseObject = try? JSONDecoder().decode(KYCStatusResponse.self, from: data) {
                        if let urlString = responseObject.form_url, let url = URL(string: urlString) {
                            return callback(url)
                        }
                    }
                }
            } else {
                if let error = error {
                    print("Registration Error: \(error)")
                }
            }
            return callback(nil)
        })
        task.resume()
    }

    func kycStatus(contractAddress: String, ethAddress: String, callback: @escaping (_ status: KYCStatus?, _ uri: String?) -> Void) {
        let req = URLRequest(url: url("/kyc/networks/\(network)/contracts/\(contractAddress)?ethereum_address=\(ethAddress)"))
        let task = dataTaskWithRequest(req, authenticated: true) { (data, response, err) in
            if err == nil, let data = data {
                do {
                    let statusResponse = try JSONDecoder().decode(KYCStatusResponse.self, from: data)
                    if let status = KYCStatus(string: statusResponse.status) {
                        if status == .complete {
                            UserDefaults.setHasCompletedKYC(true, contractAddress: contractAddress)
                        } else {
                            UserDefaults.setHasCompletedKYC(false, contractAddress: contractAddress)
                        }
                        callback(status, statusResponse.form_url)
                    }
                } catch (let e) {
                    print("/kyc json parsing error: \(e)")
                }
            }
            return callback(nil, nil)
        }
        task.resume()
    }

    func deleteKycStatus(contractAddress: String, ethAddress: String, callback: @escaping (_ success: Bool) -> Void) {
        var req = URLRequest(url: url("/kyc/networks/\(network)/contracts/\(contractAddress)?ethereum_address=\(ethAddress)"))
        req.httpMethod = "DELETE"
        let task = dataTaskWithRequest(req, authenticated: true) { (data, response, err) in
            if err == nil, let data = data {
                if let string = String(data: data, encoding: .utf8) {
                    print("string: \(string)")
                    return callback(true)
                }
            }
            return callback(false)
        }
        task.resume()
    }

    private var network: String {
        return E.isTestnet ? "ropsten" : "mainnet"
    }

}

fileprivate struct KYCStatusResponse : Codable {
    let status: String
    let form_url: String?
}
