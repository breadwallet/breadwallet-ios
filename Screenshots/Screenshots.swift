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
        
        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false
        // UI tests must launch the application that they test. Doing this in setup will make sure it happens for each test method.

        let app = XCUIApplication()
        setupSnapshot(app)
        app.launch()
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
        
        // go back to home screen if needed
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        if backButton.exists {
            backButton.tap()
        }
        
        snapshot("0HomeScreen")
        
        // tx list
        let tablesQuery = app.tables
        tablesQuery.staticTexts["Bitcoin"].tap()
        snapshot("1TxList")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        
        enum Rows: Int {
            case bitcoin = 0
            case addWallet = 4 // number of currencies
            case settings
            case security
            case support
        }
        
        let security = Rows.security.rawValue
        
        tablesQuery.cells.element(boundBy: Rows.addWallet.rawValue).tap()
        snapshot("5AddWallet")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        
        tablesQuery.cells.element(boundBy: Rows.security.rawValue).tap()
        snapshot("3Security")
        app.scrollViews.otherElements.buttons["Close"].tap()
        
        // support
        tablesQuery.cells.element(boundBy: Rows.support.rawValue).tap()
        //snapshot("4Support") // TODO: this fails with "error getting main window"
    }
    
}
