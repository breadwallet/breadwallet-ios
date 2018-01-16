//
//  Sentry.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2018-01-15.
//  Copyright © 2018 breadwallet LLC. All rights reserved.
//

import Foundation

struct SentryEvent : Codable {
    let event_id: String = UUID().uuidString.replacingOccurrences(of: "-", with: "")
    let timestamp = Date()
    let logger = "com.breadwallet.ios.logger"
    let platform = "cocoa"
    let message: String
}

struct SentryConfig : Codable {
    let sentryPubKey: String
    let sentrySecret: String
    let sentryUrl: String
}

class SentryClient {

    static let shared = SentryClient()

    private var config: SentryConfig {
        guard let file = Bundle.main.path(forResource: "Config", ofType: "plist"),
            let data = FileManager.default.contents(atPath: file),
            let config = try? PropertyListDecoder().decode(SentryConfig.self, from: data) else {
                return SentryConfig(sentryPubKey: "", sentrySecret: "", sentryUrl: "") }
        return config
    }

    func sendMessage(_ message: String, completion: @escaping()->Void) {
        sendEvent(SentryEvent(message: message), completion: completion)
    }

    private func sendEvent(_ event: SentryEvent, completion: @escaping()->Void) {
        var request = sentryRequest
        let encoder = JSONEncoder()
        if #available(iOS 10.0, *) {
            encoder.dateEncodingStrategy = .iso8601
        }
        request.httpBody = try? encoder.encode(event)

        let task = URLSession.shared.dataTask(with: request, completionHandler: {data, response, error in
            if let response = response as? HTTPURLResponse {
                if response.statusCode == 200 {
                    print("Send Event")
                } else {
                    print("Event failed to send")
                }
            }
            completion()
        })
        task.resume()
    }

    private var sentryRequest: URLRequest {
        let request = NSMutableURLRequest(url: URL(string: config.sentryUrl)!)
        request.httpMethod = "POST"
        request.setValue(authHeader(), forHTTPHeaderField: "X-Sentry-Auth")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("sentry-cocoa", forHTTPHeaderField: "User-Agent")
        return request as URLRequest
    }

    private func authHeader() -> String {
        var header = "Sentry "
        header.append("sentry_version=7,")
        header.append("sentry_client=breadwallet_ios/\(Bundle.main.infoDictionary?["CFBundleVersion"] ?? "1.0"),")
        header.append("sentry_timestamp=\(Date().timeIntervalSince1970),")
        header.append("sentry_key=\(config.sentryPubKey),")
        header.append("sentry_secret=\(config.sentrySecret)")
        return header
    }
}
