//
//  BRAPIClient+Announcements.swift
//  breadwallet
//
//  Created by Ray Vander Veen on 2019-02-07.
//  Copyright © 2018-2019 Breadwinner AG. All rights reserved.
//

import Foundation

/**
 *  Fetches data from the 'announcements' endpoint.
 */
extension BRAPIClient {
    
    func fetchAnnouncements() {
        let req = NSMutableURLRequest(url: url("/me/announcements"))
        
        if E.isDebug {
            req.setValue("all-announcements", forHTTPHeaderField: "x-features")
        }
        
        dataTaskWithRequest(req as URLRequest, authenticated: true) { [unowned self] (data, response, err) in
            if let response = response, response.statusCode == 200, let data = data, !data.isEmpty {
                do {
                    let decoder = JSONDecoder()
                    let announcements = try decoder.decode([Announcement].self, from: data)
                    if !announcements.isEmpty {
                        PromptFactory.didFetchAnnouncements(announcements: announcements)
                    }
                } catch let e {
                    self.log("error fetching announcements: \(e)")
                }
            } else {
                self.log("error fetching announcements: \(String(describing: err))")
            }
            }.resume()
    }
}
