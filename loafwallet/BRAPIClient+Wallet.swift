//
//  BRAPIClient+Wallet.swift
//  litewallet
//
//  Created by Kerry Washington on 2/29/20.
//  Copyright © 2019 Litecoin Foundation. All rights reserved.

import Foundation

private let ratesURL = "https://api.loshan.co.uk/api/v1/rates"
private let fallbackRatesURL = "https://api.loafwallet.org/api/v1/rates"

extension BRAPIClient {
    func feePerKb(_ handler: @escaping (_ fees: Fees, _ error: String?) -> Void) {
        let req = URLRequest(url: url("/fee-per-kb"))
        let task = self.dataTaskWithRequest(req) { (data, response, err) -> Void in
            //TODO: Refactor when mobile-api v0.4.0 is in prod
            let staticFees = Fees.defaultFees
            handler(staticFees, nil)
        }
        task.resume()
    }
    
    func exchangeRates(isFallback: Bool = false, _ handler: @escaping (_ rates: [Rate], _ error: String?) -> Void) {
        let request = isFallback ? URLRequest(url: URL(string: fallbackRatesURL)!) : URLRequest(url: URL(string: ratesURL)!)
        let task = dataTaskWithRequest(request) { (data, response, error) in
            if error == nil, let data = data,
                let parsedData = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) {
                if isFallback {
                    guard let array = parsedData as? [Any] else {
                        return handler([], "/rates didn't return an array")
                    }
                    handler(array.compactMap { Rate(data: $0) }, nil)
                } else {
                    guard let array = parsedData as? [Any] else {
                        return handler([], "/rates didn't return an array")
                    }
                    handler(array.compactMap { Rate(data: $0) }, nil)
                }
            } else {
                if isFallback {
                    handler([], "Error fetching from fallback url")
                } else {
                    self.exchangeRates(isFallback: true, handler)
                }
            }
        }.resume()
    }
}
 
