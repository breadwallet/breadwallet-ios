//
//  BRAPIClient+Pigeon.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2018-07-11.
//  Copyright © 2018-2019 Breadwinner AG. All rights reserved.
//

import Foundation
import SwiftProtobuf

struct Inbox: Codable {
    let entries: [InboxEntry]
}

struct InboxEntry: Codable {
    let received_time: String
    let acknowledged: Bool
    let acknowledged_time: String
    let message: String
    let cursor: String
    //let service_url: String
}

enum InboxFetchResult {
    case success([InboxEntry])
    case error
}

extension Sequence where Iterator.Element == InboxEntry {
    var unacknowledged: [InboxEntry] {
        return filter { !$0.acknowledged }
    }
}

enum SendMessageResult {
    case success
    case error
}

struct ServiceDefinition: Codable {
    let url: String
    let name: String
    let hash: String
    let created_time: String
    let updated_time: String
    let logo: String
    let description: String
    let domains: [String]
    let capabilities: [ServiceCapability]
}

struct ServiceCapability: Codable {
    struct ServiceScope: Codable {
        let name: String
        let description: String
    }

    let name: String
    let description: String
    let scopes: [ServiceScope]
}

extension BRAPIClient {
    
    func fetchInbox(afterCursor cursor: String? = nil, limit: Int = 100, callback: @escaping (InboxFetchResult) -> Void) {
        var params = ""
        if let cursor = cursor {
            params = "?after=\(cursor)&limit=\(limit)"
        }
        var req = URLRequest(url: url("/inbox\(params)"))
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        dataTaskWithRequest(req, authenticated: true, handler: { data, response, error in
            guard error == nil else {
                print("[EME] /inbox error: \(error!)")
                return callback(.error) }
            guard response?.statusCode == 200 else {
                print("[EME] /inbox response code: \(response?.statusCode ?? 0)")
                return callback(.error)
            }
            guard let data = data else { return callback(.error) }
            do {
                let inbox = try JSONDecoder().decode(Inbox.self, from: data)
                callback(.success(inbox.entries))
            } catch let error {
                print("[EME] /inbox decoding error: \(error)")
                callback(.error)
            }
        }).resume()
    }
    
    func sendAck(forCursor cursor: String) {
        var req = URLRequest(url: url("/ack"))
        req.httpMethod = "POST"
        req.httpBody = try? JSONEncoder().encode([cursor])
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        dataTaskWithRequest(req, authenticated: true, handler: { _, response, _ in
            print("[EME] ACK(\(cursor)) response: \(response?.statusCode ?? 0)")
        }).resume()
    }

    func sendMessage(envelope: MessageEnvelope, callback: ((Bool) -> Void)? = nil) {
        print("[EME] sending: \(envelope)")
        var req = URLRequest(url: url("/message"))
        req.httpMethod = "POST"
        req.httpBody = try? envelope.serializedData()
        req.setValue("application/x-protobuf", forHTTPHeaderField: "Content-Type")
        dataTaskWithRequest(req, authenticated: true, handler: { data, response, error in
            guard error == nil, let response = response else {
                print("[EME] /message error: \(error?.localizedDescription ?? "nil repsonse")")
                callback?(false)
                return
            }
            guard response.statusCode == 201 else {
                print("[EME] /message status code: \(response.statusCode)")
                if let data = data, !data.isEmpty {
                    print("[EME] /message response: \(String(data: data, encoding: .utf8) ?? "")")
                    // TODO: decode and handle error response: err_too_many_unacknowledged_messages
                }
                callback?(false)
                return
            }
            callback?(true)
        }).resume()
    }
    
    func addAssociatedKey(_ pubKey: Data, callback: @escaping (Bool) -> Void) {
        var req = URLRequest(url: url("/me/associated-keys"))
        req.httpMethod = "POST"
        req.httpBody = pubKey.base58.data(using: .utf8)
        req.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        dataTaskWithRequest(req, authenticated: true, handler: { _, response, error in
            guard error == nil, let response = response else {
                print("[EME] /associated-keys error: \(error?.localizedDescription ?? "nil repsonse")")
                return callback(false)
            }
            guard response.statusCode == 201 || ((E.isTestFlight || E.isDebug) && response.statusCode < 500) else {
                print("[EME] /associated-keys response: \(response.statusCode)")
                return callback(false)
            }
            callback(true)
        }).resume()
    }
    
    func getAssociatedKeys() {
        var req = URLRequest(url: url("/me/associated-keys"))
        req.httpMethod = "GET"
        dataTaskWithRequest(req, authenticated: true, handler: { data, _, _ in
            guard let data = data else { return }
            print("[EME] associated-keys: \(String(data: data, encoding: .utf8) ?? ""))")
        }).resume()
    }
    
    func fetchServiceInfo(serviceID: String, callback: @escaping (ServiceDefinition?) -> Void) {
        var req = URLRequest(url: url("/external/service/\(serviceID)"))
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        dataTaskWithRequest(req, authenticated: true, handler: { data, _, _ in
            guard let data = data else { return callback(nil) }
            do {
                let definition = try JSONDecoder().decode(ServiceDefinition.self, from: data)
                callback(definition)
            } catch let e {
                print("error: \(e)")
                callback(nil)
            }
        }).resume()
    }
}
