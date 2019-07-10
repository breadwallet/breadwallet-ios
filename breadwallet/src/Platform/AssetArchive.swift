//
//  AssetArchive.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2019-02-13.
//  Copyright © 2019 Breadwinner AG. All rights reserved.
//

import Foundation

open class AssetArchive {
    let name: String
    private let fileManager: FileManager
    private let archiveUrl: URL
    private let archivePath: String
    private let extractedPath: String
    let extractedUrl: URL
    private unowned let apiClient: BRAPIClient

    private var archiveExists: Bool {
        return fileManager.fileExists(atPath: archivePath)
    }

    private var extractedDirExists: Bool {
        return fileManager.fileExists(atPath: extractedPath)
    }

    var version: String? {
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
                if versions.firstIndex(of: version) == versions.count - 1 {
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
