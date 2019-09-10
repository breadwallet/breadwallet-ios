//
//  BRCoderTests.swift
//  breadwallet
//
//  Created by Samuel Sutch on 12/7/16.
//  Copyright © 2016-2019 Breadwinner AG. All rights reserved.
//

import XCTest
@testable import breadwallet

class TestObject: BRCoding {
    var string: String
    var int: Int
    var date: Date
    var stringArray: [String]

    init(string: String, int: Int, date: Date, stringArray: [String]) {
        self.string = string
        self.int = int
        self.date = date
        self.stringArray = stringArray
    }
    
    required init?(coder decoder: BRCoder) {
        string = decoder.decode("string")
        int = decoder.decode("int")
        date = decoder.decode("date")
        stringArray = decoder.decode("stringArray")
    }
    
    func encode(_ coder: BRCoder) {
        coder.encode(string, key: "string")
        coder.encode(int, key: "int")
        coder.encode(date, key: "date")
        coder.encode(stringArray, key: "stringArray")
    }
}

class BRCodingTests: XCTestCase {
    func testBasicEncodeAndDecode() {
        let orig = TestObject(string: "hello", int: 823483, date: Date(timeIntervalSince1970: 872347), stringArray: ["1", "2"])
        let dat = BRKeyedArchiver.archivedDataWithRootObject(orig)
        
        guard let new: TestObject = BRKeyedUnarchiver.unarchiveObjectWithData(dat) else {
            XCTFail("unarchived a nil object")
            return
        }
        XCTAssertEqual(orig.string, new.string)
        XCTAssertEqual(orig.int, new.int)
        XCTAssertEqual(orig.date, new.date)
        XCTAssertEqual(orig.stringArray, new.stringArray)
    }
}
