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
    
    class func logEventWithParameters(itemName: CustomEvent, properties:[String: Any]?) {
        
        Analytics.logEvent(AnalyticsEventSelectContent,
                           parameters: [
            AnalyticsParameterItemID: "id-\(itemName.hashValue)",
            AnalyticsParameterItemName: itemName.rawValue,
            AnalyticsParameterContentType: "cont",
            "customProperties": properties ?? "-Empty-"
        ]) 
    }
    
}
