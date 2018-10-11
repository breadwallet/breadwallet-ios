//
//  BRAPIClient+EmailSubscription.swift
//  breadwallet
//
//  Created by Ray Vander Veen on 2018-10-09.
//  Copyright © 2018 breadwallet LLC. All rights reserved.
//

import Foundation

extension BRAPIClient {
    
    /**
     *  Sends the given email to the server so that the user can be subscribed to email updates.
     *  The callback will be invoked and indicate whether the operation was successful.
     */
    func subscribeToEmailUpdates(emailAddress: String?, callback: @escaping (Bool) -> Void) {
        guard emailAddress != nil else { return }
        
        var req = URLRequest(url: url("/me/mailing-list-subscribe"))
        
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpMethod = "POST"
                
        let json = ["email" : emailAddress]
        let data = try? JSONSerialization.data(withJSONObject: json, options: [])
        
        req.httpBody = data
        
        dataTaskWithRequest(req, authenticated: true, handler: { data, response, error in
            guard error == nil, let response = response else {
                print("/mailing-list-subscribe error: \(error?.localizedDescription ?? "nil repsonse")")
                return callback(false)
            }

            guard response.statusCode == 200 else {
                print("/mailing-list-subscribe response: \(response.statusCode)")
                return callback(false)
            }
            
            callback(true)
            
        }).resume()
    }
    
}
