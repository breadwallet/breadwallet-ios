//
//  BRAPIClient+Bundles.swift
//  breadwallet
//
//  Created by Samuel Sutch on 3/31/17.
//  Copyright © 2017-2019 Breadwinner AG. All rights reserved.
//

import Foundation

// Platform bundle management
extension BRAPIClient {
    // updates asset bundles with names included in the AssetBundles.plist file
    // if we are in a staging/debug/test environment the bundle names will have "-staging" appended to them
    open func updateBundles(completionHandler: @escaping (_ results: [(String, Error?)]) -> Void) {
        // ensure we can create the bundle directory
        do {
            try self.ensureBundlePaths()
        } catch let e {
            // if not return the creation error for every bundle name
            return completionHandler([("INVALID", e)])
        }
        guard let path = Bundle.main.path(forResource: "AssetBundles", ofType: "plist"),
            var names = NSArray(contentsOfFile: path) as? [String] else {
                log("updateBundles unable to load bundle names")
                return completionHandler([("INVALID", BRAPIClientError.unknownError)])
        }

        if E.isDebug || E.isTestFlight {
            names = names.map { n in return n + "-staging" }
        }
        
        let grp = DispatchGroup()
        let queue = DispatchQueue.global(qos: .utility)
        var results: [(String, Error?)] = names.map { ($0, nil) }
        queue.async {
            for (resIdx, name) in names.enumerated() {
                if let archive = AssetArchive(name: name, apiClient: self) {
                    grp.enter()
                    archive.update(completionHandler: { (err) in
                        queue.async(flags: .barrier) {
                            results[resIdx] = (name, err)
                            grp.leave()
                        }
                    })
                }
            }
            grp.wait()
            completionHandler(results)
        }
    }
    
    var bundleDirUrl: URL {
        let fm = FileManager.default
        let docsUrl = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let bundleDirUrl = docsUrl.appendingPathComponent("bundles", isDirectory: true)
        return bundleDirUrl
    }
    
    fileprivate func ensureBundlePaths() throws {
        let fm = FileManager.default
        var attrs = try? fm.attributesOfItem(atPath: bundleDirUrl.path)
        if attrs == nil {
            try fm.createDirectory(atPath: bundleDirUrl.path, withIntermediateDirectories: true, attributes: nil)
            attrs = try fm.attributesOfItem(atPath: bundleDirUrl.path)
        }
    }
    
    open func getAssetVersions(_ name: String, completionHandler: @escaping ([String]?, Error?) -> Void) {
        let req = URLRequest(url: url("/assets/bundles/\(name)/versions"))
        dataTaskWithRequest(req) {(data, _, err) in
            if let err = err {
                completionHandler(nil, err)
                return
            }
            if let data = data,
                let parsed = try? JSONSerialization.jsonObject(with: data, options: []),
                let top = parsed as? NSDictionary,
                let versions = top["versions"] as? [String] {
                completionHandler(versions, nil)
            } else {
                completionHandler(nil, BRAPIClientError.malformedDataError)
            }
        }.resume()
    }
    
    open func downloadAssetArchive(_ name: String, completionHandler: @escaping (Data?, Error?) -> Void) {
        let req = URLRequest(url: url("/assets/bundles/\(name)/download"))
        dataTaskWithRequest(req) { (data, response, err) in
            if err != nil {
                return completionHandler(nil, err)
            }
            if response?.statusCode != 200 {
                return completionHandler(nil, BRAPIClientError.unknownError)
            }
            if let data = data {
                return completionHandler(data, nil)
            } else {
                return completionHandler(nil, BRAPIClientError.malformedDataError)
            }
        }.resume()
    }
    
    open func downloadAssetDiff(_ name: String, fromVersion: String, completionHandler: @escaping (Data?, Error?) -> Void) {
        let req = URLRequest(url: self.url("/assets/bundles/\(name)/diff/\(fromVersion)"))
        self.dataTaskWithRequest(req, handler: { (data, resp, err) in
            if err != nil {
                return completionHandler(nil, err)
            }
            if resp?.statusCode != 200 {
                return completionHandler(nil, BRAPIClientError.unknownError)
            }
            if let data = data {
                return completionHandler(data, nil)
            } else {
                return completionHandler(nil, BRAPIClientError.malformedDataError)
            }
        }).resume()
    }
}
