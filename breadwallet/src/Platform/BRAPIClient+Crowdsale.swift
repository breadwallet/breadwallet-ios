//
//  BRAPIClient+Crowdsale.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2017-12-04.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation

enum KYCStatus {
    case none
    case pending
    case failed
    case complete
}

extension BRAPIClient {

    func kycStatus(contractAddress: String, ethAddress: String, handler: (_ status: KYCStatus, _ error: String?) -> Void) {
        let network = E.isTestnet ? "ropsten" : "mainnet"
        let req = URLRequest(url: url("/crowdsale/\(contractAddress)/kyc/status?eth_address=\(contractAddress)&network=\(network)"))
        let task = self.dataTaskWithRequest(req) { (data, response, err) in
            if err == nil {
                do {
                    let parsedObject: Any? = try JSONSerialization.jsonObject(
                        with: data!, options: JSONSerialization.ReadingOptions.allowFragments)
                    print("parsed: \(parsedObject)")
                } catch (let e) {
                    self.log("kycStatus: error parsing json \(e)")
                }
            }
        }
        task.resume()
    }

}
