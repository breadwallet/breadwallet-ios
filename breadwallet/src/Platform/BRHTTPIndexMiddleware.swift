//
//  BRHTTPIndexMiddleware.swift
//  BreadWallet
//
//  Created by Samuel Sutch on 2/19/16.
//  Copyright (c) 2016-2019 Breadwinner AG. All rights reserved.
//

import Foundation

// BRHTTPIndexMiddleware returns index.html to any GET requests - regardless of the URL being requestd
class BRHTTPIndexMiddleware: BRHTTPFileMiddleware {
    override func handle(_ request: BRHTTPRequest, next: @escaping (BRHTTPMiddlewareResponse) -> Void) {
        if request.method == "GET" {
            let newRequest = BRHTTPRequestImpl(fromRequest: request)
            newRequest.path = request.path.rtrim(["/"]) + "/index.html"
            super.handle(newRequest) { resp in
                if resp.response == nil {
                    let newRequest = BRHTTPRequestImpl(fromRequest: request)
                    newRequest.path = "/index.html"
                    super.handle(newRequest, next: next)
                } else {
                    next(resp)
                }
            }
        } else {
            next(BRHTTPMiddlewareResponse(request: request, response: nil))
        }
    }
}
