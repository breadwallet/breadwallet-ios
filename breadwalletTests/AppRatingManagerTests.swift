//
//  AppRatingManagerTests.swift
//  breadwalletTests
//
//  Created by Ray Vander Veen on 2019-01-23.
//  Copyright © 2019 Breadwinner AG. All rights reserved.
//

import XCTest

@testable import breadwallet

class AppRatingManagerTests: XCTestCase {

    override func setUp() {
        UserDefaults.resetAll()
    }
    
    private func makeRatingManager() -> AppRatingManager {
        let mgr = AppRatingManager()
        mgr.start()
        return mgr
    }
    
    func testStartAppRatingManager() {
        XCTAssertFalse(makeRatingManager().haveSufficientLaunchesToShowPrompt)
    }

    func testNumberOfLaunches() {
        let mgr = makeRatingManager()
        
        XCTAssertFalse(mgr.haveSufficientLaunchesToShowPrompt)
        
        let launchCount = mgr.ratingLaunchCountCycle
        
        for _ in 1...launchCount { UserDefaults.appLaunchCount = UserDefaults.appLaunchCount + 1 }
        
        XCTAssertTrue(mgr.haveSufficientLaunchesToShowPrompt)
    }

}
