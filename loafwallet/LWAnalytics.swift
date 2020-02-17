//
//  Analytics.swift
//  loafwallet
//
//  Created by Kerry Washington on 2/15/20.
//  Copyright © 2020 Litecoin Foundation. All rights reserved.
//

import Foundation
import FirebaseAnalytics

class LWAnalytics {
    
    class func logEventWithParameters(itemName: CustomEvent, properties:[String: String]? = nil) {
        var parameters = [
        AnalyticsParameterItemID: "id-\(itemName.hashValue)",
        AnalyticsParameterItemName: itemName.rawValue,
        AnalyticsParameterContentType: "cont"]
        
        if let properties = properties {
            for (key, value) in properties {
                parameters[key] = value
            }
        }
        
        Analytics.logEvent(itemName.rawValue, parameters: parameters)
    }
    
}
