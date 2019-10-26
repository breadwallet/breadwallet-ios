// 
//  AuthenticationClient.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2019-08-05.
//  Copyright © 2019 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import Foundation
import BRCrypto

/// Handles user authentication and JWT token generation
struct AuthenticationClient {
    static let defaultTokenExpiration = TimeInterval(C.secondsInDay * 7)
    
    let baseURL: URL
    let urlSession: URLSession
    
    // MARK: - Public

    /// Authenticates a user with their key and returns the authenticated user credentials.
    func authenticate(apiKey: Key, clientToken: String, deviceId: String, completion: @escaping (Result<AuthUserCredentials, APIRequestError>) -> Void) {
        getUser(apiKey: apiKey, clientToken: clientToken, deviceId: deviceId) { result in
            completion(result.map { AuthUserCredentials(userId: $0.userId, userToken: $0.token, clientToken: $0.clientToken) })
        }
    }

    /// Returns a locally generated JWT for the authenticated user.
    func generateToken(for user: AuthUserCredentials, key: Key) -> Result<JWT, Error> {
        let expiration = Date().addingTimeInterval(AuthenticationClient.defaultTokenExpiration)
        return Result { try JWT(userToken: user.userToken, clientToken: user.clientToken, key: key, expiration: expiration) }
    }
    
    // MARK: - Requests
    
    private func getUser(apiKey: Key,
                         clientToken: String,
                         deviceId: String,
                         completion: @escaping (Result<AuthUser, APIRequestError>) -> Void) {
        guard var req = createRequest(.post, resource: "/users/token"),
            let signingData = clientToken.data(using: .utf8),
            apiKey.hasSecret else {
                assertionFailure()
                return completion(.failure(.requestError(nil)))
        }
        req.authorize(withToken: clientToken)
        guard let signature = CoreSigner.basicDER.sign(data32: signingData.sha256, using: apiKey),
            let pubKey = apiKey.encodeAsPublic.hexToData else {
            return completion(.failure(.requestError(nil)))
        }
        let handshake = UserHandshake(signature: signature.base64EncodedString(),
                                      pubKey: pubKey.base64EncodedString(),
                                      deviceId: deviceId)
        do {
            let body = try jsonEncoder.encode(handshake)
            req.httpBody = body
        } catch let e {
            return completion(.failure(.requestError(e)))
        }
        send(request: req, completion: completion)
    }
    
    // MARK: - Helpers
    
    private let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(DateFormatter.iso8601Full)
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()
    
    private let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .formatted(DateFormatter.iso8601Full)
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()
    
    private func makeURL(path: String, queryItems: [URLQueryItem]? = nil) -> URL? {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: true) else { return nil }
        components.path = components.path.appending(path)
        components.queryItems = queryItems
        return components.url
    }
    
    private func createRequest(_ method: HTTPMethod = .get, resource: String) -> URLRequest? {
        guard let url = makeURL(path: resource) else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = method.name
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        return req
    }
    
    private func send<T: Decodable>(request: URLRequest, completion: @escaping (Result<T, APIRequestError>) -> Void) {
        if let method = request.httpMethod, let url = request.url?.absoluteString {
            print("[AUTH] \(method) \(url)")
        }
        urlSession.dataTask(with: request) { (data, response, error) in
            if let error = error {
                return completion(.failure(.requestError(error)))
            }
            
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard 200..<299 ~= statusCode else {
                return completion(.failure(.httpError(code: statusCode)))
            }
            
            guard let data = data else {
                return completion(.failure(.dataError(nil)))
            }
            
            do {
                let value = try self.jsonDecoder.decode(T.self, from: data)
                completion(.success(value))
            } catch let decodeError {
                return completion(.failure(.dataError(decodeError)))
            }
        }.resume()
    }
    
    // MARK: Models
    
    private struct UserHandshake: Codable {
        let signature: String // base64
        let pubKey: String // base64
        let deviceId: String // uuid
    }
    
    fileprivate struct AuthUser: Codable {
        let userId: String
        let created: Date
        let lastAccess: Date
        let clientToken: String
        let token: String
        let pubKey: String
        let deviceId: String
    }
}

// MARK: - Models

/// An authenticated user and credentials for generating a JWT
struct AuthUserCredentials: Codable {
    let userId: String
    let userToken: String
    let clientToken: String
}

/// JSON Web Token
struct JWT: Codable {
    let token: String
    let expiration: Date

    var isExpired: Bool {
        return Date() > expiration
    }

    private struct Header: Codable {
        let algorithm: String = "ES256"
        let type: String = "JWT"
        
        enum CodingKeys: String, CodingKey {
            case algorithm = "alg"
            case type = "typ"
        }
    }
    
    private struct Payload: Codable {
        var subject: String
        var issuedAt: Date
        var expiration: Date
        var claimType: String
        var claimValue: String
        
        enum CodingKeys: String, CodingKey {
            case subject = "sub"
            case issuedAt = "iat"
            case expiration = "exp"
            case claimType = "brd:ct"
            case claimValue = "brd:cli"
        }
    }

    init(userToken: String,
         clientToken: String,
         key: Key,
         expiration: Date) throws {
        let header = JWT.Header()
        let payload = JWT.Payload(subject: userToken,
                                  issuedAt: Date(),
                                  expiration: expiration,
                                  claimType: "usr",
                                  claimValue: clientToken)
        self.token = try JWT.createToken(header: header, payload: payload, key: key)
        self.expiration = expiration
    }

    private static func createToken(header: JWT.Header, payload: JWT.Payload, key: Key) throws -> String {
        // use JWT expected JSON formatting
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .secondsSince1970
        
        let encodedHeader = try encoder.encode(header).base64url
        let encodedPayload = try encoder.encode(payload).base64url
        let signingString = "\(encodedHeader).\(encodedPayload)"
        guard let signingData = signingString.data(using: .utf8),
            let signature = CoreSigner.basicJOSE.sign(data32: signingData.sha256, using: key) else {
                throw EncodingError.invalidValue(signingString,
                                                 EncodingError.Context(codingPath: [], debugDescription: "unable to encode JWT payload"))
        }
        let encodedSignature = signature.base64url
        return "\(encodedHeader).\(encodedPayload).\(encodedSignature)"
    }
}

// MARK: Requests

enum APIRequestError: Error {
    case requestError(Error?)
    case httpError(code: Int)
    case dataError(Error?)
}

enum HTTPMethod: String {
    case post
    case get
    case put
    case patch
    
    var name: String { return rawValue.uppercased() }
}

// MARK: Extensions

extension URLRequest {
    mutating func authorize(withToken token: String) {
        setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }
}

private extension Encodable {
    func jsonString(with encoder: JSONEncoder = JSONEncoder()) -> String {
        guard let json = try? encoder.encode(self) else { return "" }
        return String(data: json, encoding: .utf8) ?? ""
    }
}
