//
//  BRAPIClient+Announcements.swift
//  breadwallet
//
//  Created by Ray Vander Veen on 2019-02-07.
//  Copyright © 2018 breadwallet LLC. All rights reserved.
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
        
        dataTaskWithRequest(req as URLRequest, authenticated: true) { [unowned self] (data, resp, err) in
            if let resp = resp, resp.statusCode == 200, let data = data, !data.isEmpty {
                do {
                    let json = try JSONSerialization.jsonObject(with: data, options: [])
                    guard let jsonArray = json as? [[String: AnyObject]] else { return }
                    guard !jsonArray.isEmpty else { return }
                    
                    self.announcementsFromJSONArray(jsonArray: jsonArray, completion: { (announcements) in
                        Store.trigger(name: .didFetchAnnouncements(announcements))
                    })
                    
                } catch let e {
                    self.log("error fetching announcements: \(e)")
                }
            } else {
                self.log("error fetching announcements: \(String(describing: err))")
            }
            }.resume()
    }
    
    func announcementsFromJSONArray(jsonArray: [[String: AnyObject]], completion: (([Announcement]) -> Void)?) {
        var result = [Announcement]()
        
        for announcement in jsonArray {
            result.append(Announcement(json: announcement))
        }
        
        completion?(result)
    }
    
}
