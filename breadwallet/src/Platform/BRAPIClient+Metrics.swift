//
//  BRAPIClient+Metrics.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2018-05-15.
//  Copyright © 2018 breadwallet LLC. All rights reserved.
//

import Foundation
import UIKit

extension BRAPIClient {
    
    func sendLaunchEvent(userAgent: String) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let `self` = self else { return }
            let payload = MetricsPayload(data: MetricsPayloadData.launch(LaunchData(bundles: self.bundles, userAgent: userAgent)))
            self.sendMetrics(payload: payload)
        }
    }
    
    func sendCheckoutEvent(txHash: String,
                           fromCurrency: String,
                           fromAddress: String,
                           fromAmount: String,
                           toCurrency: String,
                           toAmount: String) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            let payload = MetricsPayload(data:
                MetricsPayloadData.checkout(CheckoutData(transactionHash: txHash,
                                                         fromCurrency: fromCurrency,
                                                         fromAmount: fromAmount,
                                                         fromAddress: fromAddress,
                                                         toCurrency: toCurrency,
                                                         toAmount: toAmount,
                                                         timestamp: Int(Date().timeIntervalSince1970))))
            self?.sendMetrics(payload: payload)
        }
    }
    
    private func sendMetrics(payload: MetricsPayload) {
        guard let data = try? JSONEncoder().encode(payload) else { return }
        var req = URLRequest(url: self.url("/me/metrics"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpBody = data
        self.dataTaskWithRequest(req, authenticated: true, handler: { data, response, error in
        }).resume()
    }
    
    private var bundles: [String: String] {
        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: bundleDirUrl.path)
            let bundleNames = contents.filter { $0.contains(".tar") }.map { $0.replacingOccurrences(of: ".tar", with: "")}
            return bundleNames.reduce([String: String](), { dict, bundleName in
                var dict = dict
                dict[bundleName] = AssetArchive(name: bundleName, apiClient: self)?.version
                return dict
            })
        } catch let e {
            print("Load bundles error: \(e)")
            return [:]
        }
    }
}

fileprivate struct MetricsPayload : Encodable {
    let metric: String
    let data: MetricsPayloadData
    
    init(data: MetricsPayloadData) {
        self.metric = data.metric
        self.data = data
    }
}

fileprivate enum MetricsPayloadData: Encodable {
    case launch(LaunchData)
    case checkout(CheckoutData)
    
    var metric: String {
        switch self {
        case .launch(_):
            return "launch"
        case .checkout(_):
            return "pigeon-transaction"
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .launch(let value):
            try container.encode(value)
        case .checkout(let value):
            try container.encode(value)
        }
    }
}

fileprivate struct LaunchData: Encodable {
    let bundles: [String: String]
    let userAgent: String
    let osVersion: String = E.osVersion
    let deviceType: String = UIDevice.current.model + (E.isSimulator ? "-simulator" : "")
    
    enum CodingKeys: String, CodingKey {
        case bundles
        case userAgent = "user_agent"
        case osVersion = "os_version"
        case deviceType = "device_type"
    }
}

fileprivate struct CheckoutData: Encodable {
    let transactionHash: String
    let fromCurrency: String
    let fromAmount: String
    let fromAddress: String
    let toCurrency: String
    let toAmount: String
    let timestamp: Int
}
