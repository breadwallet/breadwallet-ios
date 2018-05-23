//
//  BRAPIClient+Metrics.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2018-05-15.
//  Copyright © 2018 breadwallet LLC. All rights reserved.
//

import Foundation

extension BRAPIClient {

    func sendLaunchEvent() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let `self` = self else { return }
            var req = URLRequest(url: self.url("/me/metrics"))
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("application/json", forHTTPHeaderField: "Accept")
            let data = LaunchData(data: BundleData(bundles: self.bundles))
            req.httpBody = try? JSONEncoder().encode(data)
            self.dataTaskWithRequest(req, authenticated: true, handler: { data, response, error in
            }).resume()
        }
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

private struct LaunchData : Codable {
    let metric = "launch"
    let data: BundleData
}

private struct BundleData: Codable {
    let bundles: [String: String]
}
