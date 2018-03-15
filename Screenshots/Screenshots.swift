//
//  Screenshots.swift
//  Screenshots
//
//  Created by Adrian Corscadden on 2017-07-02.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import XCTest

class Screenshots: XCTestCase {
        
    override func setUp() {
        super.setUp()
        
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false
        // UI tests must launch the application that they test. Doing this in setup will make sure it happens for each test method.

        let app = XCUIApplication()
        setupSnapshot(app)
        app.launch()

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testExample() {
        // Use recording to get started writing UI tests.
        // Use XCTAssert and related functions to verify your tests produce the correct results.

        snapshot("2LockScreen")
        
        let app = XCUIApplication()
        let staticText = app.collectionViews.staticTexts["5"]
        staticText.tap()
        staticText.tap()
        staticText.tap()
        staticText.tap()
        staticText.tap()
        staticText.tap()
        snapshot("0HomeScreen")
        
        // tx list
        let tablesQuery = app.tables
        tablesQuery.staticTexts["Bitcoin"].tap()
        snapshot("1TxList")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        
        // security center
        tablesQuery.cells.element(boundBy: 3).tap()
        snapshot("3Security")
        app.scrollViews.otherElements.buttons["Close"].tap()
        
        // support
        tablesQuery.cells.element(boundBy: 4).tap()
        snapshot("4Support")
    }
    
}
