//
//  CurrencyMetaDataTests.swift
//  breadwalletTests
//
//  Created by Adrian Corscadden on 2018-04-18.
//  Copyright © 2018-2019 Breadwinner AG. All rights reserved.
//

import XCTest
@testable import breadwallet

class CurrencyMetaDataTests : XCTestCase {

    func testAddingCurrencies() {
        let metaData = CurrencyListMetaData()
        let tokens = ["1", "2"]
        let tokenArray = ["erc20:1", "erc20:2"]
        metaData.addTokenAddresses(addresses: tokens)
        XCTAssert(metaData.previouslyAddedTokenAddresses == tokens, "Previously Added Token addresses should match")
        XCTAssert(metaData.enabledTokenAddresses == tokens, "Enabled token addresses should match")
        XCTAssert(metaData.hiddenTokenAddresses == [], "Hidden Token Addresses should be empty")
        XCTAssert(metaData.enabledCurrencies == tokenArray, "Enabled currencies should match")
        XCTAssert(metaData.hiddenCurrencies == [], "Hidden currencies should match")
    }

    func testAddingThenRemovingCurrencies() {
        let metaData = CurrencyListMetaData()
        let tokens = ["1", "2"]
        let tokenArray = ["erc20:1", "erc20:2"]
        metaData.addTokenAddresses(addresses: tokens)
        metaData.removeTokenAddresses(addresses: tokens)
        XCTAssert(metaData.previouslyAddedTokenAddresses == tokens, "Previously Added Token addresses should match")
        XCTAssert(metaData.enabledTokenAddresses == [], "Enabled token addresses should be empty")
        XCTAssert(metaData.hiddenTokenAddresses == tokens, "Hidden Token Addresses should match")
        XCTAssert(metaData.enabledCurrencies == [], "Enabled currencies should match")
        XCTAssert(metaData.hiddenCurrencies == tokenArray, "Hidden currencies should match")
    }

    func testRemovingSomeCurrencies() {
        let metaData = CurrencyListMetaData()
        let tokens = ["1", "2"]
        metaData.addTokenAddresses(addresses: tokens)
        metaData.removeTokenAddresses(addresses: ["2"])
        XCTAssert(metaData.previouslyAddedTokenAddresses == tokens, "Previously Added Token addresses should match")
        XCTAssert(metaData.enabledTokenAddresses == ["1"], "Enabled token addresses should match")
        XCTAssert(metaData.hiddenTokenAddresses == ["2"], "Hidden Token Addresses should match")
    }

    func testAddRemoveAddCurrencies() {
        let metaData = CurrencyListMetaData()
        let tokens = ["1", "2"]
        metaData.addTokenAddresses(addresses: tokens)
        metaData.removeTokenAddresses(addresses: ["2"])
        metaData.addTokenAddresses(addresses: ["2"])
        XCTAssert(metaData.previouslyAddedTokenAddresses == tokens, "Previously Added Token addresses should match")
        XCTAssert(metaData.enabledTokenAddresses == tokens, "Enabled token addresses should match")
        XCTAssert(metaData.hiddenTokenAddresses == [], "Hidden Token Addresses should match")
    }
    
    func testAddressAlreadyAddedIsCaseInsensitive() {
        var metaData = CurrencyListMetaData()
        let addressLowercase = "0x722dd3f80bac40c951b51bdd28dd19d435762180"
        let addressUppercase = "0x722DD3F80BAC40C951B51BDD28DD19D435762180"
        
        // add lower, test upper
        metaData.addTokenAddresses(addresses: [addressLowercase])
        XCTAssertTrue(metaData.isAddressAlreadyAdded(address: addressUppercase))
        
        // add upper, test lower
        metaData = CurrencyListMetaData()
        metaData.addTokenAddresses(addresses: [addressUppercase])
        XCTAssertTrue(metaData.isAddressAlreadyAdded(address: addressLowercase)) 
        
        // test an address not already added
        XCTAssertFalse(metaData.isAddressAlreadyAdded(address: "0x722dd3f80bac40c951b51bdd28dd112345672180"))
    }
}
