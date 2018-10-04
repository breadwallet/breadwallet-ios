//
//  BRAPIClient+Features.swift
//  breadwallet
//
//  Created by Samuel Sutch on 4/2/17.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation

extension BRAPIClient {
    static func defaultsKeyForFeatureFlag(_ name: String) -> String {
        return "ff:\(name)"
    }
    
    func updateFeatureFlags() {
        let req = URLRequest(url: url("/me/features"))
        dataTaskWithRequest(req, authenticated: true) { (data, resp, err) in
            if let resp = resp, let data = data {
                if resp.statusCode == 200 {
                    let defaults = UserDefaults.standard
                    do {
                        let j = try JSONSerialization.jsonObject(with: data, options: [])
                        let features = j as! [[String: AnyObject]]
                        for feat in features {
                            if let fn = feat["name"], let fname = fn as? String,
                                let fe = feat["enabled"], let fenabled = fe as? Bool {
                                self.log("feature \(fname) enabled: \(fenabled)")
                                defaults.set(fenabled, forKey: BRAPIClient.defaultsKeyForFeatureFlag(fname))
                            } else {
                                self.log("malformed feature: \(feat)")
                            }
                        }
                    } catch let e {
                        self.log("error loading features json: \(e)")
                    }
                }
            } else {
                self.log("error fetching features: \(String(describing: err))")
            }
            }.resume()
    }
    
    static func featureEnabled(_ flag: BRFeatureFlags) -> Bool {
        if E.isDebug || E.isTestFlight { return true }
        let defaults = UserDefaults.standard
        return defaults.bool(forKey: BRAPIClient.defaultsKeyForFeatureFlag(flag.description))
    }
}
