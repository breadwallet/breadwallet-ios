//
//  Sentry.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2018-01-15.
//  Copyright © 2018-2019 Breadwinner AG. All rights reserved.
//

import Foundation

struct SentryEvent: Codable {
    let event_id: String = UUID().uuidString.replacingOccurrences(of: "-", with: "")
    let timestamp = Date()
    let logger = "com.breadwallet.ios.logger"
    let platform = "cocoa"
    let message: String
}

class SentryClient {

    static let shared = SentryClient()

    func sendMessage(_ message: String, completion: @escaping() -> Void) {
        sendEvent(SentryEvent(message: message), completion: completion)
    }

    private func sendEvent(_ event: SentryEvent, completion: @escaping() -> Void) {
        var request = sentryRequest
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try? encoder.encode(event)

        let task = URLSession.shared.dataTask(with: request, completionHandler: {_, response, _ in
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
        let request = NSMutableURLRequest(url: URL(string: "")!) //TODO - add url
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
        header.append("sentry_key=,")
        header.append("sentry_secret=")
        return header
    }
}
