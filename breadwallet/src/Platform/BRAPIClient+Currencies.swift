//
//  BRAPIClient+Currencies.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2018-03-12.
//  Copyright © 2018-2019 Breadwinner AG. All rights reserved.
//

import Foundation

public enum APIResult<ResultType: Codable> {
    case success(ResultType)
    case error(Error)
}

public struct HTTPError: Error {
    let code: Int
}

struct FiatCurrency: Decodable {
    var name: String
    var code: String
    
    static var availableCurrencies: [FiatCurrency] = {
        guard let path = Bundle.main.path(forResource: "fiatcurrencies", ofType: "json") else {
            print("unable to locate currencies file")
            return []
        }
        
        var currencies: [FiatCurrency]?
        
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            let decoder = JSONDecoder()
            currencies = try decoder.decode([FiatCurrency].self, from: data)
        } catch let e {
            print("error parsing fiat currency data: \(e)")
        }
        
        return currencies ?? []
    }()

}

extension BRAPIClient {
    
    // MARK: Currency List
    
    /// Get the list of supported currencies and their metadata from the backend or local cache
    func getCurrencyMetaData(completion: @escaping ([CurrencyId: CurrencyMetaData]) -> Void) {
        
        let fm = FileManager.default
        guard let documentsDir = try? fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false) else { return assertionFailure() }
        let cachedFilePath = documentsDir.appendingPathComponent("currencies.json").path
        
        // If cache isn't expired, use cached data and return before the network call
        if !isCacheExpired(path: cachedFilePath, timeout: C.secondsInMinute*60) &&
            processCurrenciesCache(path: cachedFilePath, completion: completion) {
            return
        }
        
        let req = URLRequest(url: url("/currencies"))
        send(request: req, handler: { (result: APIResult<[CurrencyMetaData]>) in
            switch result {
            case .success(let currencies):
                // update cache
                do {
                    let data = try JSONEncoder().encode(currencies)
                    try data.write(to: URL(fileURLWithPath: cachedFilePath))
                } catch let e {
                    print("[CurrencyList] failed to write to cache: \(e.localizedDescription)")
                }
                processCurrencies(currencies, completion: completion)
                
            case .error(let error):
                print("[CurrencyList] error fetching tokens: \(error)")
                copyEmbeddedCurrencies(path: cachedFilePath, fileManager: fm)
                let result = processCurrenciesCache(path: cachedFilePath, completion: completion)
                assert(result, "failed to get currency list from backend or cache")
            }
        })
        
        cleanupOldTokensFile()
    }
    
    private func send<ResultType>(request: URLRequest, handler: @escaping (APIResult<ResultType>) -> Void) {
        dataTaskWithRequest(request, authenticated: true, retryCount: 0, handler: { data, response, error in
            guard error == nil, let data = data else {
                print("[API] HTTP error: \(error!)")
                return handler(APIResult<ResultType>.error(error!))
            }
            guard let statusCode = response?.statusCode, statusCode >= 200 && statusCode < 300 else {
                return handler(APIResult<ResultType>.error(HTTPError(code: response?.statusCode ?? 0)))
            }
            
            do {
                let result = try JSONDecoder().decode(ResultType.self, from: data)
                handler(APIResult<ResultType>.success(result))
            } catch let jsonError {
                print("[API] JSON error: \(jsonError)")
                handler(APIResult<ResultType>.error(jsonError))
            }
        }).resume()
    }
    
    private func cleanupOldTokensFile() {
        DispatchQueue.global(qos: .utility).async {
            let fm = FileManager.default
            guard let documentsDir = try? fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false) else { return assertionFailure() }
            let oldTokensFile = documentsDir.appendingPathComponent("tokens.json").path
            if fm.fileExists(atPath: oldTokensFile) {
                try? fm.removeItem(atPath: oldTokensFile)
            }
        }
    }
}

// MARK: - File Manager Helpers

// Converts an array of CurrencyMetaData to a dictionary keyed on uid
private func processCurrencies(_ currencies: [CurrencyMetaData], completion: ([CurrencyId: CurrencyMetaData]) -> Void) {
    let currencyMetaData = currencies.reduce(into: [CurrencyId: CurrencyMetaData](), { (dict, token) in
        dict[token.uid] = token
    })
    print("[CurrencyList] tokens updated: \(currencies.count) tokens")
    completion(currencyMetaData)
}

// Loads and processes cached currencies
private func processCurrenciesCache(path: String, completion: ([CurrencyId: CurrencyMetaData]) -> Void) -> Bool {
    guard FileManager.default.fileExists(atPath: path) else { return false }
    do {
        print("[CurrencyList] using cached token list")
        let cachedData = try Data(contentsOf: URL(fileURLWithPath: path))
        let currencies = try JSONDecoder().decode([CurrencyMetaData].self, from: cachedData)
        processCurrencies(currencies, completion: completion)
        return true
    } catch let e {
        print("[CurrencyList] error reading from cache: \(e)")
        // remove the invalid cached data
        try? FileManager.default.removeItem(at: URL(fileURLWithPath: path))
        return false
    }
}

// Copies currencies embedded in bundle if cached file doesn't exist
private func copyEmbeddedCurrencies(path: String, fileManager fm: FileManager) {
    if let embeddedFilePath = Bundle.main.path(forResource: "currencies", ofType: "json"), !fm.fileExists(atPath: path) {
        do {
            try fm.copyItem(atPath: embeddedFilePath, toPath: path)
            print("[CurrencyList] copied bundle tokens list to cache")
        } catch let e {
            print("[CurrencyList] unable to copy bundled \(embeddedFilePath) -> \(path): \(e)")
        }
    }
}

// Checks if file modification time has happened within a timeout
private func isCacheExpired(path: String, timeout: TimeInterval) -> Bool {
    guard let attr = try? FileManager.default.attributesOfItem(atPath: path) else { return true }
    guard let modificationDate = attr[FileAttributeKey.modificationDate] as? Date  else { return true }
    let difference = Date().timeIntervalSince(modificationDate)
    return difference > timeout
}
