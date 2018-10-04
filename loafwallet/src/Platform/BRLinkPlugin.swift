//
//  BRLinkPlugin.swift
//  BreadWallet
//
//  Created by Samuel Sutch on 3/10/16.
//  Copyright (c) 2016 breadwallet LLC
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

import Foundation
import SafariServices

class BRLinkPlugin: NSObject, BRHTTPRouterPlugin, SFSafariViewControllerDelegate {
    weak var controller: UIViewController?
    var hasBrowser = false
    
    init(fromViewController: UIViewController) {
        self.controller = fromViewController
        super.init()
    }
    
    func hook(_ router: BRHTTPRouter) {
        // opens any url that UIApplication.openURL can open
        // arg: "url" - the url to open
        router.get("/_open_url") { (request, match) -> BRHTTPResponse in
            if let encodedUrls = request.query["url"] , encodedUrls.count == 1 {
                if let decodedUrl = encodedUrls[0].removingPercentEncoding, let url = URL(string: decodedUrl) {
                    print("[BRLinkPlugin] /_open_url \(decodedUrl)")
                    UIApplication.shared.openURL(url)
                    return BRHTTPResponse(request: request, code: 204)
                }
            }
            return BRHTTPResponse(request: request, code: 400)
        }
        
        // opens the maps app for directions
        // arg: "address" - the destination address
        // arg: "from_point" - the origination point as a comma separated pair of floats - latitude,longitude
        router.get("/_open_maps") { (request, match) -> BRHTTPResponse in
            let invalidResp = BRHTTPResponse(request: request, code: 400)
            guard let toAddress = request.query["address"] , toAddress.count == 1 else {
                return invalidResp
            }
            guard let fromPoint = request.query["from_point"] , fromPoint.count == 1 else {
                return invalidResp
            }
            guard let url = URL(string: "http://maps.apple.com/?daddr=\(toAddress[0])&spn=\(fromPoint[0])") else {
                print("[BRLinkPlugin] /_open_maps unable to construct url")
                return invalidResp
            }
            UIApplication.shared.openURL(url)
            return BRHTTPResponse(request: request, code: 204)
        }
        
        // opens the in-app browser for the provided URL
        router.get("/_browser") { (request, _) -> BRHTTPResponse in
            if self.hasBrowser {
                return BRHTTPResponse(request: request, code: 409)
            }
            guard let toURL = request.query["url"], toURL.count == 1 else {
                return BRHTTPResponse(request: request, code: 400)
            }
            guard let escapedToURL = toURL[0].removingPercentEncoding, let url = URL(string: escapedToURL) else {
                return BRHTTPResponse(request: request, code: 400)
            }
            
            self.hasBrowser = true
            DispatchQueue.main.async {
                let browser = BRBrowserViewController()
                let req = URLRequest(url: url)
                browser.load(req)
                browser.onDone = {
                    self.hasBrowser = false
                }
                self.controller?.present(browser, animated: true, completion: nil)
            }
            return BRHTTPResponse(request: request, code: 204)
        }
        
        // opens a browser with a customized request object
        // params:
        //  {
        //    "url": "http://myirl.com",
        //    "method": "POST",
        //    "body": "stringified request body...",
        //    "headers": {"X-Header": "Blerb"}
        //    "closeOn": "http://someurl",
        //  }
        // Only the "url" parameter is required. If only the "url" parameter
        // is supplied the request acts exactly like the GET /_browser resource above
        //
        // When the "closeOn" parameter is provided the web view will automatically close
        // if the browser navigates to this exact URL. It is useful for oauth redirects
        // and the like
        router.post("/_browser") { (request, _) -> BRHTTPResponse in
            if self.hasBrowser {
                return BRHTTPResponse(request: request, code: 409)
            }
            guard let body = request.body() else {
                print("[BRLinkPlugin] POST /_browser error reading body")
                return BRHTTPResponse(request: request, code: 400)
            }
            guard let json = try? JSONSerialization.jsonObject(with: body, options: []) as? [String: Any] else {
                print("[BRLinkPlugin] POST /_browser could not deserialize json object")
                return BRHTTPResponse(request: request, code: 400)
            }
            guard let toURL = json?["url"] as? String, let url = URL(string: toURL) else {
                print("[BRLinkPlugin] POST /_browser request body did not contain a valid URL")
                return BRHTTPResponse(request: request, code: 400)
            }
            var req = URLRequest(url: url)
            if let method = json?["method"] as? String {
                req.httpMethod = method
            }
            if let body = json?["body"] as? String {
                req.httpBody = Data(body.utf8)
            }
            if let headers = json?["headers"] as? [String: String] {
                for (k, v) in headers {
                    req.addValue(v, forHTTPHeaderField: k)
                }
            }
            self.hasBrowser = true
            DispatchQueue.main.async {
                let browser = BRBrowserViewController()
                browser.load(req)
                if let closeOn = json?["closeOn"] as? String {
                    browser.closeOnURL = closeOn
                }
                browser.onDone = {
                    self.hasBrowser = false
                }
                self.controller?.present(browser, animated: true, completion: nil)
            }
            return BRHTTPResponse(request: request, code: 204)
        }
    }
}
