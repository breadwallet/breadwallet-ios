//
//  NotificationTests.swift
//  breadwalletTests
//
//  Created by Ray Vander Veen on 2019-03-06.
//  Copyright © 2019 Breadwinner AG. All rights reserved.
//

import XCTest

@testable import breadwallet

class NotificationTests: XCTestCase {

    override func setUp() {
        UserDefaults.resetAll()
    }
    
    override func tearDown() {
        UserDefaults.resetAll()
    }
    
    func testShouldShowPrompt() {

        let authorizer = NotificationAuthorizer()
        XCTAssertEqual(authorizer.launchesSinceLastDeferral, 0)
        XCTAssertEqual(UserDefaults.notificationOptInDeferralCount, 0)
        
        // test logged-out case
        Store.perform(action: RequireLogin())
        var e = expectation(description: "should not show if login required")
        authorizer.checkShouldShowOptIn(completion: { shouldShow in
            XCTAssertFalse(shouldShow)
            e.fulfill()
        })
        waitForExpectations(timeout: 1.0, handler: nil)
        
        // Showing the prompt requires an app launch count of at least two so that we don't
        // spam the user with too many messages and prompts when a wallet is first created.
        UserDefaults.appLaunchCount = 2

        // test logged-in case
        Store.perform(action: LoginSuccess())
        e = expectation(description: "should show if logged in")
        authorizer.checkShouldShowOptIn(completion: { shouldShow in
            XCTAssertTrue(shouldShow)
            e.fulfill()
        })
        waitForExpectations(timeout: 1.0, handler: nil)
        
        // Simulate the user deferring the notifications opt-in the first time.
        XCTAssertEqual(authorizer.optInDeferralCount, 0)
        authorizer.userDidDeferNotificationsOptIn()
        XCTAssertEqual(authorizer.optInDeferralCount, 1)
        
        // Check that we should not show the opt-in again without sufficient
        // app launches.
        e = expectation(description: "should not show")
        authorizer.checkShouldShowOptIn(completion: { shouldShow in
            XCTAssertFalse(shouldShow, "should not show")
            e.fulfill()
        })
        waitForExpectations(timeout: 1.0, handler: nil)

        // bump the launch count enough so that we can show the prompt again
        UserDefaults.appLaunchCount += authorizer.nagUserLaunchCountInterval
        
        e = expectation(description: "should show")
        authorizer.checkShouldShowOptIn(completion: { shouldShow in
            XCTAssertTrue(shouldShow, "should show")
            e.fulfill()
        })
        waitForExpectations(timeout: 1.0, handler: nil)

        // defer once more
        authorizer.userDidDeferNotificationsOptIn()
        UserDefaults.appLaunchCount += authorizer.nagUserLaunchCountInterval
        
        e = expectation(description: "should show")
        authorizer.checkShouldShowOptIn(completion: { shouldShow in
            XCTAssertTrue(shouldShow, "should show")
            e.fulfill()
        })
        waitForExpectations(timeout: 1.0, handler: nil)

        // defer once more, then make sure should-show no longer returns true
        authorizer.userDidDeferNotificationsOptIn()
        UserDefaults.appLaunchCount += authorizer.nagUserLaunchCountInterval
        
        e = expectation(description: "should not show after three deferrals")
        authorizer.checkShouldShowOptIn(completion: { shouldShow in
            XCTAssertFalse(shouldShow, "should not show after three deferrals")
            e.fulfill()
        })
        waitForExpectations(timeout: 1.0, handler: nil)
    }
    
}
