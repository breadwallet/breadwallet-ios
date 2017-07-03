//
//  BRAPIClient+Bundles.swift
//  breadwallet
//
//  Created by Samuel Sutch on 3/31/17.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation

open class AssetArchive {
    let name: String
    private let fileManager: FileManager
    private let archiveUrl: URL
    private let archivePath: String
    private let extractedPath: String
    let extractedUrl: URL
    private let apiClient: BRAPIClient
    
    private var archiveExists: Bool {
        return fileManager.fileExists(atPath: archivePath)
    }
    
    private var extractedDirExists: Bool {
        return fileManager.fileExists(atPath: extractedPath)
    }
    
    private var version: String? {
        guard let archiveContents = try? Data(contentsOf: archiveUrl) else {
            return nil
        }
        return archiveContents.sha256.hexString
    }
    
    init?(name: String, apiClient: BRAPIClient) {
        self.name = name
        self.apiClient = apiClient
        self.fileManager = FileManager.default
        let bundleDirUrl = apiClient.bundleDirUrl
        archiveUrl = bundleDirUrl.appendingPathComponent("\(name).tar")
        extractedUrl = bundleDirUrl.appendingPathComponent("\(name)-extracted", isDirectory: true)
        archivePath = archiveUrl.path
        extractedPath = extractedUrl.path
    }
    
    func update(completionHandler: @escaping (_ error: Error?) -> Void) {
        do {
            try ensureExtractedPath()
        //If directory creation failed due to file existing
        } catch let error as NSError where error.code == 512 && error.domain == NSCocoaErrorDomain {
            do {
                try fileManager.removeItem(at: apiClient.bundleDirUrl)
                try fileManager.createDirectory(at: extractedUrl, withIntermediateDirectories: true, attributes: nil)
            } catch let e {
                return completionHandler(e)
            }
        } catch let e {
            return completionHandler(e)
        }
        if !archiveExists {
            // see if the archive was shipped with the app
            copyBundledArchive()
        }
        if !archiveExists {
            // we do not have the archive, download a fresh copy
            return downloadCompleteArchive(completionHandler: completionHandler)
        }
        apiClient.getAssetVersions(name) { (versions, err) in
            DispatchQueue.global(qos: .utility).async {
                if let err = err {
                    print("[AssetArchive] could not get asset versions. error: \(err)")
                    return completionHandler(err)
                }
                guard let versions = versions, let version = self.version else {
                    return completionHandler(BRAPIClientError.unknownError)
                }
                if versions.index(of: version) == versions.count - 1 {
                    // have the most recent version
                    print("[AssetArchive] already at most recent version of bundle \(self.name)")
                    do {
                        try self.extractArchive()
                        return completionHandler(nil)
                    } catch let e {
                        print("[AssetArchive] error extracting bundle: \(e)")
                        return completionHandler(BRAPIClientError.unknownError)
                    }
                } else {
                    // need to update the version
                    self.downloadAndPatchArchive(fromVersion: version, completionHandler: completionHandler)
                }
            }
        }
    }
    
    fileprivate func downloadCompleteArchive(completionHandler: @escaping (_ error: Error?) -> Void) {
        apiClient.downloadAssetArchive(name) { (data, err) in
            DispatchQueue.global(qos: .utility).async {
                if let err = err {
                    print("[AssetArchive] error downloading complete archive \(self.name) error=\(err)")
                    return completionHandler(err)
                }
                guard let data = data else {
                    return completionHandler(BRAPIClientError.unknownError)
                }
                do {
                    try data.write(to: self.archiveUrl, options: .atomic)
                    try self.extractArchive()
                    return completionHandler(nil)
                } catch let e {
                    print("[AssetArchive] error extracting complete archive \(self.name) error=\(e)")
                    return completionHandler(e)
                }
            }
        }
    }
    
    fileprivate func downloadAndPatchArchive(fromVersion: String, completionHandler: @escaping (_ error: Error?) -> Void) {
        apiClient.downloadAssetDiff(name, fromVersion: fromVersion) { (data, err) in
            DispatchQueue.global(qos: .utility).async {
                if let err = err {
                    print("[AssetArchive] error downloading asset path \(self.name) \(fromVersion) error=\(err)")
                    return completionHandler(err)
                }
                guard let data = data else {
                    return completionHandler(BRAPIClientError.unknownError)
                }
                let fm = self.fileManager
                let diffPath = self.apiClient.bundleDirUrl.appendingPathComponent("\(self.name).diff").path
                let oldBundlePath = self.apiClient.bundleDirUrl.appendingPathComponent("\(self.name).old").path
                do {
                    if fm.fileExists(atPath: diffPath) {
                        try fm.removeItem(atPath: diffPath)
                    }
                    if fm.fileExists(atPath: oldBundlePath) {
                        try fm.removeItem(atPath: oldBundlePath)
                    }
                    try data.write(to: URL(fileURLWithPath: diffPath), options: .atomic)
                    try fm.moveItem(atPath: self.archivePath, toPath: oldBundlePath)
                    _ = try BRBSPatch.patch(
                        oldBundlePath, newFilePath: self.archivePath, patchFilePath: diffPath)
                    try fm.removeItem(atPath: diffPath)
                    try fm.removeItem(atPath: oldBundlePath)
                    try self.extractArchive()
                    return completionHandler(nil)
                } catch let e {
                    // something failed, clean up whatever we can, next attempt
                    // will download fresh
                    _ = try? fm.removeItem(atPath: diffPath)
                    _ = try? fm.removeItem(atPath: oldBundlePath)
                    _ = try? fm.removeItem(atPath: self.archivePath)
                    print("[AssetArchive] error applying diff \(self.name) error=\(e)")
                }
            }
        }
    }
    
    fileprivate func ensureExtractedPath() throws {
        if !extractedDirExists {
            try fileManager.createDirectory(
                atPath: extractedPath, withIntermediateDirectories: true, attributes: nil
            )
        }
    }
    
    fileprivate func extractArchive() throws {
        try BRTar.createFilesAndDirectoriesAtPath(extractedPath, withTarPath: archivePath)
    }
    
    fileprivate func copyBundledArchive() {
        if let bundledArchiveUrl = Bundle.main.url(forResource: name, withExtension: "tar") {
            do {
                try fileManager.copyItem(at: bundledArchiveUrl, to: archiveUrl)
                print("[AssetArchive] used bundled archive for \(name)")
            } catch let e {
                print("[AssetArchive] unable to copy bundled archive `\(name)` \(bundledArchiveUrl) -> \(archiveUrl): \(e)")
            }
        }
    }
}

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
        var results: [(String, Error?)] = names.map { v in return (v, nil) }
        queue.async {
            var i = 0
            for name in names {
                if let archive = AssetArchive(name: name, apiClient: self) {
                    let resIdx = i
                    grp.enter()
                    archive.update(completionHandler: { (err) in
                        objc_sync_enter(results)
                        results[resIdx] = (name, err)
                        objc_sync_exit(results)
                        grp.leave()
                    })
                }
                i += 1
            }
            grp.wait()
            completionHandler(results)
        }
    }
    
    fileprivate var bundleDirUrl: URL {
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
        dataTaskWithRequest(req) {(data, resp, err) in
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
