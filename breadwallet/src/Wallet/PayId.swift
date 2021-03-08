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

enum ResolvableError: Error {
    case invalidPayID
    case badResponse
    case currencyNotSupported
    case invalidAddress
}

protocol Resolvable {
    init?(address: String)
    var type: ResolvableType { get }
    func fetchAddress(forCurrency currency: Currency, callback: @escaping (Result<(String, String?), ResolvableError>) -> Void)
}

enum ResolvableType {
    case payId
    case fio
    
    var label: String {
        switch self {
        case .payId:
            return "PayString"
        case .fio:
            return "FIO"
        }
    }
}

struct ResolvedAddress {
    let humanReadableAddress: String
    let cryptoAddress: String
    let label: String
}

enum ResolvableFactory {
    static func resolver(_ address: String) -> Resolvable? {
        if let fio = Fio(address: address) {
            return fio
        }
        
        if let payId = PayId(address: address) {
            return payId
        }
        
        return nil
    }
}

private class Fio: Resolvable {
    
    private let address: String
    
    let type: ResolvableType = .fio
    
    required init?(address: String) {
        self.address = address
        guard isValidAddress(address) else { return nil }
    }
    
    func fetchAddress(forCurrency currency: Currency, callback: @escaping (Result<(String, String?), ResolvableError>) -> Void) {
        let url = URL(string: "https://api.fio.services/v1/chain/get_pub_address")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let body = [
            "fio_address": address,
            "chain_code": currency.network.currency.code.uppercased(),
            "token_code": currency.code.uppercased()
        ]
        
        let data = try? JSONEncoder().encode(body)
        request.httpBody = data
  
        URLSession.shared.dataTask(with: request, completionHandler: { data, _, _ in
            guard let data = data else { callback(.failure(.badResponse)); return }
            print("[fio] data: \(String(data: data, encoding: .utf8)!)")
            
            if (try? JSONDecoder().decode(FioError.self, from: data)) != nil {
                callback(.failure(.currencyNotSupported))
                return
            }
            
            do {
                let response = try JSONDecoder().decode(FioResponse.self, from: data)
                callback(.success((response.address(), response.tag())))
            } catch _ {
                callback(.failure(.currencyNotSupported))
            }
        }).resume()
    }
    
    private func isValidAddress(_ address: String) -> Bool {
        let pattern = ".+\\@.+"
        let range = address.range(of: pattern, options: .regularExpression)
        return range != nil
    }
    
    private struct FioResponse: Codable {
        let public_address: String
        
        func address() -> String {
            let components = public_address.components(separatedBy: "?dt=")
            if !components.isEmpty {
                return components[0]
            } else {
                return ""
            }
        }
        
        func tag() -> String? {
            let components = public_address.components(separatedBy: "?dt=")
            if components.count == 2 {
                return components[1]
            } else {
                return nil
            }
        }
    }
    
    private struct FioError: Codable {
        let message: String
    }
}

private class PayId: Resolvable {
    
    let type: ResolvableType = .payId
    
    private let separator = "$"
    private let address: String
    
    required init?(address: String) {
        self.address = address
        guard isValidAddress(address) else { return nil }
    }
    
    // response: (String, String?) == (cryptoAddress, destinationTag(optional) )
    func fetchAddress(forCurrency currency: Currency, callback: @escaping (Result<(String, String?), ResolvableError>) -> Void) {
        guard currency.payId != nil else { callback(.failure(.currencyNotSupported)); return }
        let components = address.components(separatedBy: separator)
        guard components.count == 2, !components[0].isEmpty, !components[1].isEmpty else {
            callback(.failure(.invalidPayID)); return
        }
        
        let name = components[0]
        let domain = components[1]
        guard let url = URL(string: "https://\(domain)/\(name)") else { callback(.failure(.invalidPayID)); return }
        var request = URLRequest(url: url)
        request.addValue("application/payid+json", forHTTPHeaderField: "Accept")
        request.addValue("1.0", forHTTPHeaderField: "PayID-Version")
        
        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data else { callback(.failure(.badResponse)); return }
            guard let response = try? JSONDecoder().decode(PayIdResponse.self, from: data) else {
                callback(.failure(.badResponse)); return }
            guard let first = response.addresses.first(where: { currency.doesMatchPayId($0) }) else { callback(.failure(.currencyNotSupported)); return }
            callback(.success((first.addressDetails.address, first.addressDetails.tag)))
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
    let tag: String?
}
