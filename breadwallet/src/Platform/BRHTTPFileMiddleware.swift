//
//  BRHTTPFileMiddleware.swift
//  BreadWallet
//
//  Created by Samuel Sutch on 2/8/16.
//  Copyright (c) 2016-2019 Breadwinner AG. All rights reserved.
//

import Foundation

open class BRHTTPFileMiddleware: BRHTTPMiddleware {
    var baseURL: URL
    var debugURL: URL?
    
    init(baseURL: URL, debugURL: URL? = nil) {
        self.baseURL = baseURL
        self.debugURL = debugURL
    }
    
    open func handle(_ request: BRHTTPRequest, next: @escaping (BRHTTPMiddlewareResponse) -> Void) {
        var fileURL: URL!
        var body: Data!
        var contentTypeHint: String?
        var headers = [String: [String]]()
        if debugURL == nil {
            // fetch the file locally
            fileURL = baseURL.appendingPathComponent(request.path.ltrim(["/"]))
            let fm = FileManager.default
            // read the file attributes
            guard let attrs = try? fm.attributesOfItem(atPath: fileURL.path) else {
                print("[BRHTTPServer] file not found: \(String(describing: fileURL))")
                return next(BRHTTPMiddlewareResponse(request: request, response: nil))
            }
            // generate an etag
            let etag = (attrs[FileAttributeKey.modificationDate] as? Date ?? Date()).description.md5()
            headers["ETag"] = [etag]
            var modified = true
            // if the client sends an if-none-match header, determine if we have a newer version of the file
            if let etagHeaders = request.headers["if-none-match"], !etagHeaders.isEmpty {
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
                }
            }).resume()
            _ = grp.wait(timeout: .now() + .seconds(30))
            if body == nil {
                print("[BRHTTPServer] DEBUG file not found \(String(describing: fileURL))")
                return next(BRHTTPMiddlewareResponse(request: request, response: nil))
            }
        }
        
        headers["Content-Type"] = [contentTypeHint ?? fileURL.contentType]
        
        do {
            guard let privReq = request as? BRHTTPRequestImpl else { return assertionFailure() }
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
                    "Content-Type": [fileURL.contentType]
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
}

fileprivate extension URL {
    var contentType: String {
        let ext = self.pathExtension
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
