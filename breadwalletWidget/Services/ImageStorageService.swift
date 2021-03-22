// 
//  ImageStorageService.swift
//  breadwalletWidgetExtension
//
//  Created by stringcode on 18/02/2021.
//  Copyright © 2021 Breadwinner AG. All rights reserved.
//
//  See the LICENSE file at the project root for license information.
//

import Foundation

protocol ImageStoreService: class {
    func loadImagesIfNeeded()
    func bgFolder() -> URL
    func noBgFolder() -> URL
    func imageFolder() -> URL
}

// MARK: - DefaultImageStoreService

class DefaultImageStoreService: ImageStoreService {
    
    func loadImagesIfNeeded() {
        guard needsToRefreshImages() else {
            return
        }
        
        guard let tarURL = Bundle.main.url(forResource: Constant.tokensFileName,
                                           withExtension: "tar") else {
            return
        }
        
        let fileManager = FileManager.default
        
        if fileManager.fileExists(atPath: imageFolder().path) {
            try? fileManager.removeItem(at: imageFolder())
        }
        
        try? BRTar.createFilesAndDirectoriesAtPath(imageFolder().path,
                                                   withTarPath: tarURL.path)
        markFilesExtracted()
    }
    
    func bgFolder() -> URL {
        return DefaultImageStoreService.bgFolder
    }
    
    func noBgFolder() -> URL {
        return DefaultImageStoreService.noBgFolder
    }
    
    func imageFolder() -> URL {
        return DefaultImageStoreService.imageFolder
    }
}

// MARK: - Utilities

private extension DefaultImageStoreService {
        
    func needsToRefreshImages() -> Bool {
        let defautls = UserDefaults.standard
        let lastVersion = defautls.string(forKey: Constant.refreshedVersionKey) ?? ""
        return lastVersion != currentVersionString() && isRunningInWidgetExtension()
    }
    
    func markFilesExtracted() {
        UserDefaults.standard.set(currentVersionString(),
                                  forKey: Constant.refreshedVersionKey)
        UserDefaults.standard.synchronize()
    }
    
    func isRunningInWidgetExtension() -> Bool {
        return Bundle.main.bundleIdentifier?.contains("breadwalletWidget") ?? false
    }
    
    func currentVersionString() -> String {
        var versionString = Bundle.main.releaseVersionNumber ?? ""
        versionString += " - "
        versionString += Bundle.main.buildVersionNumber ?? ""
        return versionString
    }
    
    static var bgFolder: URL {
        return imageFolder.appendingPathComponent(Constant.bgFolder)
    }
    
    static var noBgFolder: URL {
        return imageFolder.appendingPathComponent(Constant.noBgFolder)
    }
    
    static var imageFolder: URL {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory,
                                             in: .userDomainMask)[0]
        return documentsURL.appendingPathComponent(Constant.imageFolder)
    }
}

// MARK: - Constants

private extension DefaultImageStoreService {
    
    enum Constant {
        static let refreshedVersionKey = "lastRefreshVersionKey"
        static let tokensFileName = "brd-tokens"
        static let imageFolder = "brd-tokens"
        static let noBgFolder = "white-no-bg"
        static let bgFolder = "white-square-bg"
    }
}
