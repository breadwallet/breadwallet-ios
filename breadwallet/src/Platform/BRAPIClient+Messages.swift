//
//  BRAPIClient+Messages.swift
//  breadwallet
//
//  Created by Ray Vander Veen on 2019-06-04.
//  Copyright © 2019 breadwallet LLC. All rights reserved.
//

import Foundation

//
// Interfaces with the /me/messages endpoint to fetch in-app notifications etc.
//

enum BRDMessageType: String {
    case inApp
    
    func type() -> String { return rawValue }
}

class BRDMessage: Decodable {
    
    // Keys that appear in the JSON for the message sent by the server.
    enum Keys: String, CodingKey {
        case id
        case message_id
        case type
        case title
        case body
        case cta
        case cta_url
        case image_url
    }
    
    var id: String?
    var type: String?
    var messageId: String?
    var title: String?
    var body: String?
    var cta: String?
    var ctaUrl: String?
    var imageUrl: String?
}

extension BRAPIClient {
    
    func checkMessages(callback: @escaping ([BRDMessage]?) -> Void) {
        let path = "/me/messages"
        let req = NSMutableURLRequest(url: url(path))
        
        dataTaskWithRequest(req as URLRequest, authenticated: true) { [unowned self] (data, response, err) in
            if let response = response, response.statusCode == 200, let data = data, !data.isEmpty {
                
                var messages: [BRDMessage]?
                
                do {
                    let decoder = JSONDecoder()
                    
                    // converts JSON keys with underscores to equivalent camelcase
                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                    
                    messages = try decoder.decode([BRDMessage].self, from: data)
                    
                } catch let e {
                    self.log("error fetching messages: \(e)")
                }
                
                callback(messages)
                
            } else {
                self.log("error fetching messages: \(String(describing: err))")
            }}.resume()
    }
}
