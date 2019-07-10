//
//  ASADataFormatter.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2019-05-01.
//  Copyright © 2019 Breadwinner AG. All rights reserved.
//

import Foundation

//
// Formats Apple Search ads attribution info for our metrics
//
// ADClient.shared().requestAttributionDetails returns data in the following format:
// {:Version3.1 {:iad-country-or-region "US", :iad-lineitem-name "Search", :iad-click-date "2019-03-09T23:06:01Z", :iad-campaign-id "1234", :iad-conversion-type "Download"}}
//
// Our metrics only needs the object for Key 'Version3.1'. This class extracts the required object.

// Apple Search Ads Data formatter
class ASADataFormatter {
    
    private let prefix = "iad"
    
    //Formats Apple Search Ads attribution info into a format that
    //can be accepted by our metrics endpoint.
    func extractAttributionInfo(_ input: [String: NSObject]?) -> AnyCodable? {
        guard let input = input else { return nil }
        var output: AnyCodable?
        
        //Searches for an object with keys prefixed by 'iad'
        for (_, value) in input {
            if let dictionary = value as? NSDictionary {
                dictionary.allKeys.forEach {
                    if let nestedKey = $0 as? String, nestedKey.contains(prefix) {
                        output = AnyCodable(value: dictionary)
                    }
                }
            }
        }
        return output
    }
}
