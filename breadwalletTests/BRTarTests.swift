//
//  BRTarTests.swift
//  breadwallet
//
//  Created by Samuel Sutch on 12/7/16.
//  Copyright © 2016-2019 Breadwinner AG. All rights reserved.
//

import XCTest
@testable import breadwallet

class BRTarTests: XCTestCase {
    var fileUrl: URL?
    
    override func setUp() {
        // download a test tar file
        let fm = FileManager.default
        let url = URL(string: "https://s3.amazonaws.com/breadwallet-assets/bread-buy/7f5bc5c6cc005df224a6ea4567e508491acaffdc2e4769e5262a52f5b785e261.tar")!
        let documentsUrl =  fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let destinationUrl = documentsUrl.appendingPathComponent(url.lastPathComponent)
        if fm.fileExists(atPath: destinationUrl.path) {
            print("file already exists [\(destinationUrl.path)]")
            fileUrl = destinationUrl
        } else if let dataFromURL = try? Data(contentsOf: url){
            if (try? dataFromURL.write(to: destinationUrl, options: [.atomic])) != nil {
                print("file saved [\(destinationUrl.path)]")
                fileUrl = destinationUrl
            } else {
                XCTFail("error saving file")
            }
        } else {
            XCTFail("error downloading file")
        }
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testExtractTar() {
        guard let fileUrl = fileUrl else { XCTFail("file url not defined"); return }
        let fm = FileManager.default
        let docsPath = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let destPath = docsPath.appendingPathComponent("extracted_files")
        do {
            try BRTar.createFilesAndDirectoriesAtPath(destPath.path, withTarPath: fileUrl.path)
        } catch let e {
            XCTFail("failed to extract tar file with \(e)")
        }
    }
    
}
