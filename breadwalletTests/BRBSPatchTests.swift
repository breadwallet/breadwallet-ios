//
//  BRBSPatchTests.swift
//  breadwallet
//
//  Created by Samuel Sutch on 12/7/16.
//  Copyright © 2016-2019 Breadwinner AG. All rights reserved.
//

import XCTest
@testable import breadwallet

class BRBSPatchTests: XCTestCase {
    var bundle1Url: URL?
    var bundle2Url: URL?
    var patchUrl: URL?
    
    override func setUp() {
        // download test files
        func download(_ urlStr: String, resultingUrl: inout URL?) {
            let fm = FileManager.default
            let url = URL(string: urlStr)!
            let documentsUrl =  fm.urls(for: .documentDirectory, in: .userDomainMask).first!
            let destinationUrl = documentsUrl.appendingPathComponent(url.lastPathComponent)
            if fm.fileExists(atPath: destinationUrl.path) {
                print("file already exists [\(destinationUrl.path)]")
                resultingUrl = destinationUrl
            } else if let dataFromURL = try? Data(contentsOf: url){
                if (try? dataFromURL.write(to: destinationUrl, options: [.atomic])) != nil {
                    print("file saved [\(destinationUrl.path)]")
                    resultingUrl = destinationUrl
                } else {
                    XCTFail("error saving file")
                }
            } else {
                XCTFail("error downloading file")
            }
        }
        download("https://s3.amazonaws.com/breadwallet-assets/bread-buy/bundle.tar", resultingUrl: &bundle1Url)
        download("https://s3.amazonaws.com/breadwallet-assets/bread-buy/bundle2.tar", resultingUrl: &bundle2Url)
        download("https://s3.amazonaws.com/breadwallet-assets/bread-buy/bundle_bundle2.bspatch", resultingUrl: &patchUrl)
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testPatch() {
        guard let bundle1Url = bundle1Url, let bundle2Url = bundle2Url, let patchUrl = patchUrl
            else { XCTFail("test files not downloaded successfully"); return }
        let fm = FileManager.default
        let docsPath = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let destPath = docsPath.appendingPathComponent("bundle3.tar")
        if fm.fileExists(atPath: destPath.path) {
            do {
                try fm.removeItem(atPath: destPath.path)
            } catch { XCTFail("unable to remove old test file") }
        }
        var x: UnsafeMutablePointer<CUnsignedChar>? = nil
        do {
            x = try BRBSPatch.patch(bundle1Url.path, newFilePath: destPath.path, patchFilePath: patchUrl.path)
        } catch let e {
            XCTFail("failed to patch file: \(e)")
        }
        let b2contents = try! Data(contentsOf: bundle2Url)
        let b2contentsRaw = UnsafeMutablePointer<CUnsignedChar>(mutating: (b2contents as NSData).bytes.bindMemory(to: CUnsignedChar.self, capacity: b2contents.count))
        print("should be bytes len \(b2contents.count)")
        let iseq = b2contentsRaw == x
        print("is eq \(iseq)")
        let b3contents = try! Data(contentsOf: destPath)
        if b2contents != b3contents {
            XCTFail("patch did not create an identical file")
        }
    }
}
