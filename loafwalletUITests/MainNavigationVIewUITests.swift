//
//  MainNavigationVIewUITests.swift
//  loafwalletUITests
//
//  Created by Kerry Washington on 12/14/19.
//  Copyright © 2019 Litecoin Foundation. All rights reserved.
//

import XCTest

class MainNavigationVIewUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testTabBarHistoryTab() {
        let tabBarsQuery = app.tabBars
        tabBarsQuery.buttons["History"].tap()
    }
    
    func testTabBarReceiveTab() {
        let tabBarsQuery = app.tabBars
        tabBarsQuery.buttons["Receive"].tap()
    }
    
    func testTabBarSendTab() {
        let tabBarsQuery = app.tabBars
        tabBarsQuery.buttons["Send"].tap()
    }
    
    func testTabBarBuyTab() {
        let tabBarsQuery = app.tabBars
        tabBarsQuery.buttons["Buy"].tap()
    }
     
    func testDisplayContentController() {
        //contentController:UIViewController
        ///TBD TabBarViewController: 350
    }
 
}
