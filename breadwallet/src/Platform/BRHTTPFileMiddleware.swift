//
//  BRHTTPFileMiddleware.swift
//  BreadWallet
//
//  Created by Samuel Sutch on 2/8/16.
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


@objc open class BRHTTPFileMiddleware: NSObject, BRHTTPMiddleware {
    var baseURL: URL!
    var debugURL: URL?
    
    init(baseURL: URL, debugURL: URL? = nil) {
        super.init()
        self.baseURL = baseURL
        self.debugURL = debugURL
    }
    
    open func handle(_ request: BRHTTPRequest, next: @escaping (BRHTTPMiddlewareResponse) -> Void) {
        var fileURL: URL!
        var body: Data!
        var contentTypeHint: String? = nil
        var headers = [String: [String]]()
        if debugURL == nil {
            // fetch the file locally
            fileURL = baseURL.appendingPathComponent(request.path)
            let fm = FileManager.default
            // read the file attributes
            guard let attrs = try? fm.attributesOfItem(atPath: fileURL.path) else {
                print("[BRHTTPServer] file not found: \(fileURL)")
                return next(BRHTTPMiddlewareResponse(request: request, response: nil))
            }
            // generate an etag
            let etag = (attrs[FileAttributeKey.modificationDate] as? Date ?? Date()).description.md5()
            headers["ETag"] = [etag]
            var modified = true
            // if the client sends an if-none-match header, determine if we have a newer version of the file
            if let etagHeaders = request.headers["if-none-match"] , etagHeaders.count > 0 {
                let etagHeader = etagHeaders[0]
                if etag == etagHeader {
                    modified = false
                }
            }
            if modified {
                guard let bb = try? Data(contentsOf: fileURL) else {
                    return next(BRHTTPMiddlewareResponse(request: request, response: nil))
                }
                body = bb
            } else {
                return next(BRHTTPMiddlewareResponse(
                    request: request, response: BRHTTPResponse(request: request, code: 304)))
            }
        } else {
            // download the file from the debug endpoint
            fileURL = debugURL!.appendingPathComponent(request.path)
            let req = URLRequest(url: fileURL)
            let grp = DispatchGroup()
            grp.enter()
            URLSession.shared.dataTask(with: req, completionHandler: { (dat, resp, err) -> Void in
                defer {
                    grp.leave()
                }
                if err != nil {
                    return
                }
                if let dat = dat, let resp = resp as? HTTPURLResponse {
                    body = dat
                    contentTypeHint = resp.allHeaderFields["Content-Type"] as? String
                } else {
                    
                }
            }).resume()
            _ = grp.wait(timeout: DispatchTime.now() + Double(Int64(30) * Int64(NSEC_PER_SEC)) / Double(NSEC_PER_SEC))
            if body == nil {
                print("[BRHTTPServer] DEBUG file not found \(fileURL)")
                return next(BRHTTPMiddlewareResponse(request: request, response: nil))
            }
        }
        
        headers["Content-Type"] = [contentTypeHint ?? detectContentType(URL: fileURL)]
        
        do {
            let privReq = request as! BRHTTPRequestImpl
            let rangeHeader = try privReq.rangeHeader()
            if rangeHeader != nil {
                let (end, start) = rangeHeader!
                let length = end - start
                let range = NSRange(location: start, length: length + 1)
                guard range.location + range.length <= body.count else {
                    let r =  BRHTTPResponse(
                        request: request, statusCode: 418, statusReason: "Request Range Not Satisfiable",
                        headers: nil, body: nil)
                    return next(BRHTTPMiddlewareResponse(request: request, response: r))
                }
                let subDat = body.subdata(in: start..<(start + range.length))
                let headers = [
                    "Content-Range": ["bytes \(start)-\(end)/\(body.count)"],
                    "Content-Type": [detectContentType(URL: fileURL)]
                ]
                var ary = [UInt8](repeating: 0, count: subDat.count)
                (subDat as NSData).getBytes(&ary, length: subDat.count)
                let r =  BRHTTPResponse(
                    request: request, statusCode: 200, statusReason: "OK", headers: headers, body: ary)
                return next(BRHTTPMiddlewareResponse(request: request, response: r))
            }
        } catch {
            let r = BRHTTPResponse(
                request: request, statusCode: 400, statusReason: "Bad Request", headers: nil,
                body: [UInt8]("Invalid Range Header".utf8))
            return next(BRHTTPMiddlewareResponse(request: request, response: r))
        }
        
        var ary = [UInt8](repeating: 0, count: body.count)
        body.copyBytes(to: &ary, count: body.count)
        let r = BRHTTPResponse(
            request: request,
            statusCode: 200,
            statusReason: "OK",
            headers: headers,
            body: ary)
        return next(BRHTTPMiddlewareResponse(request: request, response: r))
    }
    
    fileprivate func detectContentType(URL url: URL) -> String {
        let ext = url.pathExtension
        switch ext {
        case "ttf":
            return "application/font-truetype"
        case "woff":
            return "application/font-woff"
        case "otf":
            return "application/font-opentype"
        case "svg":
            return "image/svg+xml"
        case "html":
            return "text/html"
        case "png":
            return "image/png"
        case "jpeg", "jpg":
            return "image/jpeg"
        case "css":
            return "text/css"
        case "js":
            return "application/javascript"
        case "json":
            return "application/json"
        default:
            return "application/octet-stream"
        }
    }
}
