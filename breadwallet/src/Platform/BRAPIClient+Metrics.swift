//
//  BRAPIClient+Metrics.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2018-05-15.
//  Copyright © 2018-2019 Breadwinner AG. All rights reserved.
//

import Foundation
import UIKit
import iAd
import AdSupport

// swiftlint:disable function_parameter_count

extension BRAPIClient {
    
    func sendLaunchEvent(userAgent: String) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let `self` = self else { return }
            self.getAttributionDetails { attributionInfo in
                let idfa = ASIdentifierManager.shared().advertisingIdentifier.uuidString
                let payload = MetricsPayload(data: MetricsPayloadData.launch(LaunchData(bundles: self.bundles,
                                                                                        userAgent: userAgent,
                                                                                        idfa: idfa,
                                                                                        attributionInfo: attributionInfo)))
                self.sendMetrics(payload: payload)
            }
        }
    }

    func sendCheckoutEvent(status: Int,
                           identifier: String,
                           service: String,
                           fromCurrency: String,
                           fromAddress: String,
                           fromAmount: String,
                           toCurrency: String,
                           toAmount: String,
                           toAddress: String,
                           txHash: String?,
                           error: Int?) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            let payload = MetricsPayload(data:
                MetricsPayloadData.checkout(CheckoutData(status: status,
                                                         identifier: identifier,
                                                         service: service,
                                                         transactionHash: txHash,
                                                         fromCurrency: fromCurrency,
                                                         fromAmount: fromAmount,
                                                         fromAddress: fromAddress,
                                                         toCurrency: toCurrency,
                                                         toAmount: toAmount,
                                                         toAddress: toAddress,
                                                         error: error,
                                                         timestamp: Int(Date().timeIntervalSince1970))))
            self?.sendMetrics(payload: payload)
        }
    }
    
    func sendEnableSegwit() {
        sendMetrics(payload: MetricsPayload.enableSegWit)
    }
    
    func sendViewLegacyAddress() {
        sendMetrics(payload: MetricsPayload.viewLegacyAddress)
    }
    
    private func sendMetrics(payload: MetricsPayload) {
        guard let data = try? JSONEncoder().encode(payload) else { return }
        var req = URLRequest(url: self.url("/me/metrics"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpBody = data
        self.dataTaskWithRequest(req, authenticated: true, handler: { _, _, _ in
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
    
    private func getAttributionDetails(completion: @escaping (AnyCodable) -> Void) {
        ADClient.shared().requestAttributionDetails({ (attributionDetails, error) in
            if let error = error {
                print("error fetching attribution details: \(error.localizedDescription)")
            }
            if let attributionInfo = ASADataFormatter().extractAttributionInfo(attributionDetails) {
                completion(attributionInfo)
            } else {
                completion(AnyCodable(value: ""))
            }
        })
    }
}

private struct MetricsPayload: Encodable {
    let metric: String
    let data: MetricsPayloadData
    
    init(data: MetricsPayloadData) {
        self.metric = data.metric
        self.data = data
    }
}

private enum MetricsPayloadData: Encodable {
    case launch(LaunchData)
    case checkout(CheckoutData)
    case enableSegWit(EnableSegWitData)
    case viewLegacyAddress(ViewLegacyAddressData)
    
    var metric: String {
        switch self {
        case .launch:
            return "launch"
        case .checkout:
            return "pigeon-transaction"
        case .enableSegWit:
            return "segWit"
        case .viewLegacyAddress:
            return "segWit"
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .launch(let value):
            try container.encode(value)
        case .checkout(let value):
            try container.encode(value)
        case .enableSegWit(let value):
            try container.encode(value)
        case .viewLegacyAddress(let value):
            try container.encode(value)
        }
    }
}

extension MetricsPayload {
    static var enableSegWit: MetricsPayload {
        return MetricsPayload(data: MetricsPayloadData.enableSegWit(EnableSegWitData()))
    }
    
    static var viewLegacyAddress: MetricsPayload {
        return MetricsPayload(data: MetricsPayloadData.viewLegacyAddress(ViewLegacyAddressData()))
    }
}

private struct LaunchData: Encodable {
    let bundles: [String: String]
    let userAgent: String
    let idfa: String
    let attributionInfo: AnyCodable
    let osVersion: String = E.osVersion
    let deviceType: String = UIDevice.current.model + (E.isSimulator ? "-simulator" : "")
    let applicationId: String = Bundle.main.bundleIdentifier ?? "unknown"
    
    enum CodingKeys: String, CodingKey {
        case bundles
        case userAgent = "user_agent"
        case idfa
        case osVersion = "os_version"
        case deviceType = "device_type"
        case attributionInfo = "apple_search_ads"
        case applicationId = "application_id"
    }
}

private struct CheckoutData: Encodable {
    let status: Int
    let identifier: String
    let service: String
    let transactionHash: String?
    let fromCurrency: String
    let fromAmount: String
    let fromAddress: String
    let toCurrency: String
    let toAmount: String
    let toAddress: String
    let error: Int?
    let timestamp: Int
}

private struct EnableSegWitData: Encodable {
    let eventType = "enableSegWit"
    let timestamp = Int(Date().timeIntervalSince1970)
}

private struct ViewLegacyAddressData: Encodable {
    let eventType = "viewLegacyAddress"
    let timestamp = Int(Date().timeIntervalSince1970)
}
