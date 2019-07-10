//
//  ASADataFormatterTests.swift
//  breadwalletTests
//
//  Created by Adrian Corscadden on 2019-05-01.
//  Copyright © 2019 Breadwinner AG. All rights reserved.
//

import XCTest

@testable import breadwallet

private let expectedOutput = (["iad-country-or-region": "US", "iad-lineitem-name": "Search" ] as NSObject)
private let expectedOutputString = "{\"iad-country-or-region\":\"US\",\"iad-lineitem-name\":\"Search\"}"
private let extraData = (["bar": "buzz", "bizz": "bass"] as NSObject)

class ASADataFormatterTests: XCTestCase {
    
    let formatter = ASADataFormatter()
    let normalInput: [String: NSObject] = ["Version3.1": expectedOutput]
    let extraKeyInput: [String: NSObject] = ["Version3.1": expectedOutput, "Foo": extraData]
    let differentKeyName: [String: NSObject] = ["Version800": expectedOutput]
    
    func testEmptyInput() {
        XCTAssertNil(formatter.extractAttributionInfo(nil))
    }
    
    func testNormalInput() {
        processInput(normalInput)
    }
    
    func testExtraKey() {
        processInput(extraKeyInput)
    }
    
    func testDifferentKeyName() {
        processInput(differentKeyName)
    }
    
    private func processInput(_ input: [String: NSObject]) {
        let output = formatter.extractAttributionInfo(input)
        XCTAssertNotNil(output)
        let outputData = try? JSONEncoder().encode(output)
        XCTAssertNotNil(outputData)
        let outputString = String(data: outputData!, encoding: .utf8)
        XCTAssert(outputString == expectedOutputString)
    }
    
}
