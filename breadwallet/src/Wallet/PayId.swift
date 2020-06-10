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

enum PayIdError: Error {
    case invalidPayID
    case badResponse
    case currencyNotSupported
    case invalidAddress
}

class PayId {
    
    private let separator = "$"
    private let address: String
    
    init?(address: String) {
        self.address = address
        guard isValidAddress(address) else { return nil }
    }
    
    func fetchAddress(forCurrency currency: Currency, callback: @escaping (Result<String, PayIdError>) -> Void) {
        guard currency.payId != nil else { callback(.failure(.currencyNotSupported)); return }
        let components = address.components(separatedBy: separator)
        guard components.count == 2, !components[0].isEmpty, !components[1].isEmpty else {
            callback(.failure(.invalidPayID)); return
        }
        
        let name = components[0]
        let domain = components[1]
        let url = URL(string: "https://\(domain)/\(name)")!
        var request = URLRequest(url: url)
        request.addValue("application/payid+json", forHTTPHeaderField: "Accept")
        request.addValue("1.0", forHTTPHeaderField: "PayID-Version")
        
        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data else { callback(.failure(.badResponse)); return }
            guard let response = try? JSONDecoder().decode(PayIdResponse.self, from: data) else {
                callback(.failure(.badResponse)); return }
            guard let first = response.addresses.first(where: { currency.doesMatchPayId($0) }) else { callback(.failure(.currencyNotSupported)); return }
            callback(.success(first.addressDetails.address))
        }.resume()
    }
    
    private func isValidAddress(_ address: String) -> Bool {
        let pattern = ".+\\$.+"
        let range = address.range(of: pattern, options: .regularExpression)
        return range != nil
    }
    
}

struct PayIdResponse: Codable {
    let payId: String?
    let addresses: [PayIdAddress]
}

struct PayIdAddress: Codable {
    let paymentNetwork: String
    let environment: String
    let addressDetailsType: String
    let addressDetails: PayIdAddressDetails
}

struct PayIdAddressDetails: Codable {
    let address: String
}
