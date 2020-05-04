// 
//  PaymentPath.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2020-04-28.
//  Copyright © 2020 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import Foundation

private let domainRegex = ""

class PaymentPath {
    
    private let address: String
    
    init?(address: String) {
        self.address = address
        guard isValidAddress(address) else { return nil }
    }
    
    func fetchAddress(forCurrency currency: Currency, callback: @escaping (String?) -> Void) {
        guard let id = currency.payId else { callback(nil); return }
        let components = address.components(separatedBy: "$")
        guard components.count == 2, !components[0].isEmpty, !components[1].isEmpty else {
            callback(nil); return
        }
        
        let name = components[0]
        let domain = components[1]
        let url = URL(string: "http://\(domain)/\(name)")!
        var request = URLRequest(url: url)
        
        request.addValue("application/\(id)+json", forHTTPHeaderField: "Accept")
        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data else { callback(nil); return }
            guard let response = try? JSONDecoder().decode(PayIdResponse.self, from: data) else {
                callback(nil); return }
            callback(response.addressDetails.address)
        }.resume()
    }
    
    private func isValidAddress(_ address: String) -> Bool {
        let pattern = ".*\\$.*"
        let range = address.range(of: pattern, options: .regularExpression)
        return range != nil
    }
    
}

struct PayIdResponse: Codable {
    let addressDetailType: String
    let addressDetails: PayIdAddress
}

struct PayIdAddress: Codable {
    let address: String
}
