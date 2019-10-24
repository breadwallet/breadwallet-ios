//
//  BRLinkPlugin.swift
//  BreadWallet
//
//  Created by Samuel Sutch on 3/10/16.
//  Copyright (c) 2016-2019 Breadwinner AG. All rights reserved.
//

import Foundation
import SafariServices

// swiftlint:disable cyclomatic_complexity

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
        router.get("/_open_url") { (request, _) -> BRHTTPResponse in
            if let encodedUrls = request.query["url"], encodedUrls.count == 1 {
                if let decodedUrl = encodedUrls[0].removingPercentEncoding, let url = URL(string: decodedUrl) {
                    print("[BRLinkPlugin] /_open_url \(decodedUrl)")
                    UIApplication.shared.open(url)
                    return BRHTTPResponse(request: request, code: 204)
                }
            }
            return BRHTTPResponse(request: request, code: 400)
        }
        
        // opens the maps app for directions
        // arg: "address" - the destination address
        // arg: "from_point" - the origination point as a comma separated pair of floats - latitude,longitude
        router.get("/_open_maps") { (request, _) -> BRHTTPResponse in
            let invalidResp = BRHTTPResponse(request: request, code: 400)
            guard let toAddress = request.query["address"], toAddress.count == 1 else {
                return invalidResp
            }
            guard let fromPoint = request.query["from_point"], fromPoint.count == 1 else {
                return invalidResp
            }
            guard let url = URL(string: "http://maps.apple.com/?daddr=\(toAddress[0])&spn=\(fromPoint[0])") else {
                print("[BRLinkPlugin] /_open_maps unable to construct url")
                return invalidResp
            }
            UIApplication.shared.open(url)
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
                browser.modalPresentationStyle = .fullScreen
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
            guard let toURL = json["url"] as? String, let url = URL(string: toURL) else {
                print("[BRLinkPlugin] POST /_browser request body did not contain a valid URL")
                return BRHTTPResponse(request: request, code: 400)
            }
            var req = URLRequest(url: url)
            if let method = json["method"] as? String {
                req.httpMethod = method
            }
            if let body = json["body"] as? String {
                req.httpBody = Data(body.utf8)
            }
            if let headers = json["headers"] as? [String: String] {
                for (k, v) in headers {
                    req.addValue(v, forHTTPHeaderField: k)
                }
            }
            self.hasBrowser = true
            DispatchQueue.main.async {
                let browser = BRBrowserViewController()
                browser.load(req)
                if let closeOn = json["closeOn"] as? String {
                    browser.closeOnURL = closeOn
                }
                browser.onDone = {
                    self.hasBrowser = false
                }
                browser.modalPresentationStyle = .fullScreen
                self.controller?.present(browser, animated: true, completion: nil)
            }
            return BRHTTPResponse(request: request, code: 204)
        }
    }
}
