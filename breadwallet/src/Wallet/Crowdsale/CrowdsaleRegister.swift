//
//  CrowdsaleRegister.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-12-07.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation

class CrowdsaleRegister {

    func register(firstName: String, lastName: String, email: String, countryCode: String, callback: @escaping ((URL?) -> Void)) {
        let params = KycParams(first_name: firstName, last_name: lastName, email: email, redirect_uri: "http://google.ca")
        let encodedData = try? JSONEncoder().encode(params)
        let url = URL(string: "https://stagecrowdapi.breadapp.com/kyc")!
        let request = NSMutableURLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = encodedData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let task = URLSession.shared.dataTask(with: request as URLRequest, completionHandler: { (data, response, error) in
            if error == nil {
                if let body = try? JSONDecoder().decode(KycResponse.self, from: data!) {
                    if let url = URL(string: body.redirect_uri) {
                        return callback(url)
                    }
                }
            }
            return callback(nil)
        })
        task.resume()
    }

}

fileprivate struct KycParams : Codable {
    let first_name: String
    let last_name: String
    let email: String
    let redirect_uri: String
}

fileprivate struct KycResponse : Codable {
    let redirect_uri: String
}
