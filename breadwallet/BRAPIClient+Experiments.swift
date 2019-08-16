//
//  BRAPIClient+Experiments.swift
//  breadwallet
//
//  Created by Ray Vander Veen on 8/14/19.
//  Copyright © 2019 breadwallet LLC. All rights reserved.
//

import Foundation

/**
 * An individual experiment.
 */
struct Experiment: Decodable {
    var name: String?
    var active: Bool = false
}

/**
 *  Valid experiment names. This should be updated when experiments are added or removed
 *  from the server.
 */
public enum ExperimentName: String {
    case atmFinder = "map"
}

/**
 *  API client extension for fetching experiments from the server.
 */
extension BRAPIClient {
    
    // Called on startup, a foreground event, or when network reachability is regained.
    func updateExperiments() {
        
        let req = URLRequest(url: url("/me/experiments"))
        
        dataTaskWithRequest(req, authenticated: true) { (data, resp, err) in
            if let resp = resp, let data = data, resp.statusCode == 200 {
                
                var experiments = [Experiment]()
                
                do {
                    experiments = try JSONDecoder().decode([Experiment].self, from: data)
                } catch let e {
                    self.log("error fetching experiments: \(e)")
                }
                
                _ = Store.perform(action: UpdateExperiments(experiments))

            } else {
                self.log("error fetching experiments: \(String(describing: err))")
            }
            }.resume()
    }
    
}
