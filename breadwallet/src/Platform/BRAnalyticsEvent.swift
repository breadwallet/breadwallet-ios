//
//  BRAnalyticsEvent.swift
//  breadwallet
//
//  Created by Ray Vander Veen on 2018-12-12.
//  Copyright © 2018-2019 Breadwinner AG. All rights reserved.
//

import Foundation

typealias Attributes = [String: String]

enum BRAnalyticsEventName: String {
    case sessionId  = "sessionId"
    case time       = "time"
    case eventName  = "eventName"
    case metaData   = "metadata"
}

struct BRAnalyticsEvent {
    let sessionId: String
    let time: TimeInterval
    let eventName: String
    let attributes: Attributes
    
    var dictionary: [String: Any] {
        var result: [String: Any] = [String: Any]()
        
        result[BRAnalyticsEventName.sessionId.rawValue] = sessionId
        result[BRAnalyticsEventName.time.rawValue] = Int(time)
        result[BRAnalyticsEventName.eventName.rawValue] = eventName
        
        if !attributes.keys.isEmpty {
            var metaData: [[String: String]] = [[String: String]]()
            
            for key in attributes.keys {
                if let value = attributes[key] {
                    metaData.append(["key": key, "value": value])                        
                }
            }
            
            result[BRAnalyticsEventName.metaData.rawValue] = metaData
        }
        
        return result
    }
}
