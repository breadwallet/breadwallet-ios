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
    
    enum Keys: String, CodingKey {
        case name
        case active
        case meta
    }
    
    var name: String?
    var active: Bool = false
    var meta: Decodable?
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        do {
            name = try container.decodeIfPresent(String.self, forKey: .name)
            active = try container.decodeIfPresent(Bool.self, forKey: .active) ?? false
            if let meta = try container.decodeIfPresent(BrowserExperimentMetaData.self, forKey: .meta) {
                self.meta = meta
            }
        } catch {   // missing element
        }
    }

}

/**
 *  Meta data specific to an experiment that launches a browser.
 */
struct BrowserExperimentMetaData: Decodable {
    var url: String?
    var closeOn: String?
}

extension Experiment: Equatable {
    static func == (lhs: Experiment, rhs: Experiment) -> Bool {
        return lhs.name == rhs.name
    }
}

/**
 *  Valid experiment names. This should be updated when experiments are added or removed
 *  from the server.
 */
public enum ExperimentName: String {
    case atmFinder = "map"
    case buyAndSell = "buy-sell-menu-button"
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
