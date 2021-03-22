// 
//  ExAPIResource.swift
//  breadwallet
//
//  Created by Jared Wheeler on 2/10/21.
//  Copyright © 2021 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import Foundation

public typealias ResultCompletion<Value> = (Result<Value, Error>) -> Void

public class ExternalAPIClient {
    
    // MARK: - Singleton
    
    static let shared = ExternalAPIClient()
    private init() { }
    
    // MARK: - Public
    
    public func send<T: ExternalAPIRequest>(_ request: T, completion: @escaping ResultCompletion<T.Response>) {
        guard let endpoint = self.endpoint(for: request) else { return }
        URLSession.shared.dataTask(with: URLRequest(url: endpoint)) { data, response, error in
            if let data = data {
                do {
                    let result = try JSONDecoder().decode(T.Response.self, from: data)
                    DispatchQueue.main.async {
                        completion(.success(result))
                    }
                } catch {
                    DispatchQueue.main.async {
                        completion(.failure(ExternalAPIError.decoding))
                    }
                }
            } else if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }.resume()
    }
    
    // MARK: - Private
    
    private func endpoint<T: ExternalAPIRequest>(for request: T) -> URL? {
        guard let url = URL(string: request.resourceName, relativeTo: URL(string: request.hostName)),
              var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            fatalError("Bad url: \(request.hostName)/\(request.resourceName)")
        }
        return url
    }
}

public enum ExternalAPIError: Error {
    case encoding
    case decoding
    case server(message: String)
}
