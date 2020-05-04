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

enum PaymentPathError: Error {
    case invalidPayID
    case badResponse
    case currencyNotSupported
    case invalidAddress
}

class PaymentPath {
    
    private let address: String
    
    init?(address: String) {
        self.address = address
        guard isValidAddress(address) else { return nil }
    }
    
    func fetchAddress(forCurrency currency: Currency, callback: @escaping (Result<String, PaymentPathError>) -> Void) {
        guard let id = currency.payId else { callback(.failure(.currencyNotSupported)); return }
        let components = address.components(separatedBy: "$")
        guard components.count == 2, !components[0].isEmpty, !components[1].isEmpty else {
            callback(.failure(.invalidPayID)); return
        }
        
        let name = components[0]
        let domain = components[1]
        let url = URL(string: "http://\(domain)/\(name)")!
        var request = URLRequest(url: url)
        
        request.addValue("application/\(id)+json", forHTTPHeaderField: "Accept")
        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data else { callback(.failure(.badResponse)); return }
            guard let response = try? JSONDecoder().decode(PayIdResponse.self, from: data) else {
                callback(.failure(.badResponse)); return }
            if currency.isValidAddress(response.addressDetails.address) {
                callback(.success(response.addressDetails.address))
            } else {
                print("invalid address: \(response.addressDetails.address)")
                callback(.failure(.invalidAddress))
            }
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
